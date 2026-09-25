import Foundation

/// One entry per line, blanks and `#` lines dropped: `/etc/shells` and the
/// worktree file lists share the grammar; see Docs/design/hooks.md.
public enum LineList {
  public static func entries(in text: String) -> [String] {
    text.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }
  }
}
