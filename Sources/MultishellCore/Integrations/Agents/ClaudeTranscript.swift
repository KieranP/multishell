import Foundation

/// Whether Claude has a finished task's notice still queued at its Stop,
/// which starts a turn of its own after it; see Docs/design/agents.md.
enum ClaudeTranscript {
  /// Far more than a turn writes, and a read of a few milliseconds where a
  /// whole transcript runs to 23 MB.
  static let tailBytes = 4 << 20

  private static let noticeOpening = "<task-notification>"
  private static let markers = [noticeOpening, "stop_hook_summary"].map { Data($0.utf8) }

  /// `false` where the file cannot be read, which is what an older build said.
  static func turnFollows(atPath path: String) -> Bool {
    guard let handle = FileHandle(forReadingAtPath: path) else { return false }
    defer { try? handle.close() }
    guard let end = try? handle.seekToEnd() else { return false }
    let start = end > UInt64(tailBytes) ? end - UInt64(tailBytes) : 0
    guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else {
      return false
    }
    return turnFollows(in: data, startsAtFileStart: start == 0)
  }

  /// A notice queued since the last Stop and neither taken off the queue nor
  /// handed to the model; by timestamp, the file's order not being time's.
  static func turnFollows(in data: Data, startsAtFileStart: Bool) -> Bool {
    var lines = data.split(separator: UInt8(ascii: "\n"))
    if !startsAtFileStart, !lines.isEmpty { lines.removeFirst() }
    var lastStop = ""
    var queued: [String: String] = [:]
    var delivered: [String: String] = [:]
    for line in lines where markers.contains(where: { line.range(of: $0) != nil }) {
      guard let entry = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
        let time = entry["timestamp"] as? String
      else { continue }
      if entry["type"] as? String == "system", entry["subtype"] as? String == "stop_hook_summary" {
        lastStop = max(lastStop, time)
      } else if let (id, isQueued) = notice(in: entry) {
        if isQueued {
          queued[id] = max(queued[id] ?? "", time)
        } else {
          delivered[id] = max(delivered[id] ?? "", time)
        }
      }
    }
    return queued.contains { id, time in time > lastStop && (delivered[id] ?? "") < time }
  }

  /// The task a notice names, and whether this entry queues it rather than
  /// takes it off the queue or hands it to the model as a prompt or an aside.
  private static func notice(in entry: [String: Any]) -> (id: String, isQueued: Bool)? {
    let text: Any?
    let isQueued: Bool
    switch entry["type"] as? String {
    case "queue-operation":
      let operation = entry["operation"] as? String
      guard operation == "enqueue" || operation == "remove" else { return nil }
      text = entry["content"]
      isQueued = operation == "enqueue"
    case "user":
      text = (entry["message"] as? [String: Any])?["content"]
      isQueued = false
    case "attachment":
      text = (entry["attachment"] as? [String: Any])?["prompt"]
      isQueued = false
    default:
      return nil
    }
    guard let text = text as? String,
      text.drop(while: \.isWhitespace).hasPrefix(noticeOpening),
      let match = text.firstMatch(of: /<task-id>\s*([^<\s]+)\s*<\/task-id>/)
    else { return nil }
    return (String(match.1), isQueued)
  }
}
