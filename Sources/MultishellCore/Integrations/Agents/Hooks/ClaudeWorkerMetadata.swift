import Foundation

/// The file Claude keeps beside its transcript for each worker: which worker
/// launched it and what Claude calls it. No hook says either; see agents.md.
struct ClaudeWorkerMetadata: Equatable {
  /// The worker that launched this one, `nil` for one the agent launched itself.
  var parentID: String?
  /// The skill a worker runs as, or else its task's description.
  var name: String?

  init(parentID: String? = nil, name: String? = nil) {
    self.parentID = parentID
    self.name = name
  }

  init?(json data: Data) {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    parentID = (object["parentAgentId"] as? String).flatMap { Self.isSafeWorkerID($0) ? $0 : nil }
    name = [object["name"], object["description"]].lazy
      .compactMap { $0 as? String }.first { !$0.isEmpty }
  }

  /// `<project>/<session>.jsonl` keeps its workers in `<project>/<session>/subagents/`.
  static func path(ofWorker workerID: String, transcriptPath: String) -> String {
    URL(fileURLWithPath: transcriptPath).deletingPathExtension()
      .appendingPathComponent("subagents")
      .appendingPathComponent("agent-\(workerID).meta.json").path
  }

  /// Far more than the few hundred bytes Claude writes there.
  private static let maximumBytes = 64 << 10

  /// `nil` where the file is missing or unreadable, as it is at the worker's
  /// start, which Claude announces before writing it.
  static func read(ofWorker workerID: String, transcriptPath: String) -> ClaudeWorkerMetadata? {
    guard isSafeWorkerID(workerID),
      let handle = FileHandle(
        forReadingAtPath: path(ofWorker: workerID, transcriptPath: transcriptPath))
    else { return nil }
    defer { try? handle.close() }
    guard let data = try? handle.read(upToCount: maximumBytes) else { return nil }
    return ClaudeWorkerMetadata(json: data)
  }

  /// An id is put into a path, so one that could leave the folder is no worker's.
  private static func isSafeWorkerID(_ id: String) -> Bool {
    !id.isEmpty && id.count <= SessionStateReport.maximumIdentifierLength
      && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
  }
}
