import Foundation

/// Whether Claude is asking the user its own question. Its permission
/// notification says "permission" for that too and names no tool.
extension ClaudeTranscript {
  private static let questionToolName = "AskUserQuestion"

  private static let toolUseMarker = Data(#""tool_use""#.utf8)
  private static let toolResultMarker = Data(#""tool_result""#.utf8)

  /// `false` where the file cannot be read: the notification keeps its words.
  static func asksQuestion(atPath path: String) -> Bool {
    guard let tail = tail(atPath: path) else { return false }
    return asksQuestion(in: tail.data, startsAtFileStart: tail.startsAtFileStart)
  }

  /// The last tool call is the question tool and has no result yet. Read from
  /// the end, as a tail holds hundreds of tool lines and only the last counts.
  static func asksQuestion(in data: Data, startsAtFileStart: Bool) -> Bool {
    var answered: Set<String> = []
    for line in wholeLines(of: data, startsAtFileStart: startsAtFileStart).reversed()
    where line.range(of: toolUseMarker) != nil || line.range(of: toolResultMarker) != nil {
      guard let entry = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
        let content = (entry["message"] as? [String: Any])?["content"] as? [[String: Any]]
      else { continue }
      for block in content where block["type"] as? String == "tool_result" {
        if let id = block["tool_use_id"] as? String { answered.insert(id) }
      }
      guard let lastCall = content.last(where: { $0["type"] as? String == "tool_use" }),
        let id = lastCall["id"] as? String
      else { continue }
      return !answered.contains(id) && lastCall["name"] as? String == questionToolName
    }
    return false
  }
}
