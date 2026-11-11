import Foundation

/// The extra arguments an agent is started with, as typed. Split into words
/// here rather than handed to a shell; see Docs/design/agents/launch-arguments.md.
public enum AgentFlags {
  /// The line as an argument list, placeholders resolved. An unknown one is
  /// left as typed, so the mistake shows in the tab.
  public static func arguments(
    _ line: String,
    values: [WorktreePlaceholder: String],
  ) -> [String] {
    ShellWords.split(line).map { expanded($0, values: values) }
  }

  /// One pass over what was typed. A token appearing in a value is text the
  /// user named something, not a placeholder; see Docs/design/agents/launch-arguments.md.
  private static func expanded(_ text: String, values: [WorktreePlaceholder: String]) -> String {
    var result = ""
    var rest = Substring(text)
    while let open = rest.range(of: "{{"),
      let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex)
    {
      result += rest[..<open.lowerBound]
      let name = String(rest[open.upperBound..<close.lowerBound])
      if let placeholder = WorktreePlaceholder(rawValue: name), let value = values[placeholder] {
        result += value
      } else {
        result += rest[open.lowerBound..<close.upperBound]
      }
      rest = rest[close.upperBound...]
    }
    return result + rest
  }
}
