import Foundation

/// What Claude's undocumented transcript says of its background workers, read
/// at a Stop since a hook can land late or never come; see agents.md.
enum ClaudeTranscript {
  /// Far more than was written since any worker still on a roster ended,
  /// and a read of a few milliseconds where a whole file runs to 23 MB.
  static let tailBytes = 4 << 20

  private static let noticeOpening = "<task-notification>"
  private static let markers = [noticeOpening, "TaskStop", "SendMessage"].map { Data($0.utf8) }

  /// `nil` where the file cannot be read.
  static func endedWorkers(atPath path: String) -> [String]? {
    guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? handle.close() }
    guard let end = try? handle.seekToEnd() else { return nil }
    let start = end > UInt64(tailBytes) ? end - UInt64(tailBytes) : 0
    guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else {
      return nil
    }
    return endedWorkers(in: data, fromStart: start == 0)
  }

  /// Most recent last. A notice or a TaskStop ends a worker, and a message
  /// sent to it afterwards starts it again.
  static func endedWorkers(in data: Data, fromStart: Bool) -> [String] {
    var lines = data.split(separator: UInt8(ascii: "\n"))
    if !fromStart, !lines.isEmpty { lines.removeFirst() }
    var ended: [String] = []
    for line in lines where markers.contains(where: { line.range(of: $0) != nil }) {
      guard let entry = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
      else { continue }
      if let id = noticedTask(in: entry) {
        ended.removeAll { $0 == id }
        ended.append(id)
      }
      for (name, input) in toolCalls(in: entry) {
        if name == "TaskStop", let id = input["task_id"] as? String {
          ended.removeAll { $0 == id }
          ended.append(id)
        } else if name == "SendMessage", let id = input["to"] as? String {
          ended.removeAll { $0 == id }
        }
      }
    }
    return ended
  }

  /// The task a completion notice names, in the three places one is written:
  /// queued, handed to the model as a prompt, or folded into a running turn.
  private static func noticedTask(in entry: [String: Any]) -> String? {
    let text: Any? =
      switch entry["type"] as? String {
      case "queue-operation": entry["content"]
      case "user": (entry["message"] as? [String: Any])?["content"]
      case "attachment": (entry["attachment"] as? [String: Any])?["prompt"]
      default: nil
      }
    guard let text = text as? String,
      text.drop(while: \.isWhitespace).hasPrefix(noticeOpening),
      let match = text.firstMatch(of: /<task-id>\s*([^<\s]+)\s*<\/task-id>/)
    else { return nil }
    return String(match.1)
  }

  private static func toolCalls(in entry: [String: Any]) -> [(String, [String: Any])] {
    guard entry["type"] as? String == "assistant",
      let blocks = (entry["message"] as? [String: Any])?["content"] as? [[String: Any]]
    else { return [] }
    return blocks.compactMap { block in
      guard block["type"] as? String == "tool_use", let name = block["name"] as? String,
        let input = block["input"] as? [String: Any]
      else { return nil }
      return (name, input)
    }
  }
}
