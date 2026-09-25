/// The glyph drawn where an agent is at a prompt: a case per project the app
/// has art for, letters for the rest. See Docs/design/agents.md.
public enum AgentMark: Equatable, Hashable, Sendable {
  case claude
  case codex
  case copilot
  case openCode
  case gemini
  case monogram(String)

  /// The marks the app has art for, in no order that matters. A test walks
  /// them to check every one still loads.
  public static let drawn: [AgentMark] = [.claude, .codex, .copilot, .openCode, .gemini]

  /// One letter from each of the first two words, or the first two of one
  /// word. Non-letters are passed over, so `claude-3` reads as `Cl`.
  static func letters(of name: String) -> String {
    let words = name.split(whereSeparator: { !$0.isLetter }).filter { !$0.isEmpty }
    guard let first = words.first else { return "?" }
    if words.count > 1, let second = words.dropFirst().first?.first {
      return first.prefix(1).uppercased() + String(second).lowercased()
    }
    return first.prefix(1).uppercased() + first.dropFirst().prefix(1).lowercased()
  }
}
