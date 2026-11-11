import Foundation
import MultishellCore

/// A title a pane's program reported, as the strip, the sidebar, the board and
/// the switcher draw it. The command line keeps the raw one. See tabs-and-groups/tab-strip.md.
enum ShownPaneTitle {
  /// Read once, every shown title being measured against it.
  static let accountHome = FileManager.default.homeDirectoryForCurrentUser.path
  /// Claude Code's `✳` and Gemini CLI 0.66's `✋ ⏲ ◇ ✦`, matched by first scalar
  /// so an emoji form's variation selector rides along.
  private static let statusGlyphs: Set<Unicode.Scalar> = ["✳", "✋", "⏲", "◇", "✦"]
  /// Spinner frames: braille, and Claude Code 2.1.318's working `◐ ◑ ◒ ◓`.
  private static let spinnerFrames: [ClosedRange<UInt32>] = [0x2800...0x28FF, 0x25D0...0x25D3]

  /// Without its leading status glyph and trailing blanks, and a directory inside
  /// the worktree relative to it: "Shell" at its root.
  static func shown(_ reported: String, worktreePath: String?, home: String) -> String {
    let title = withoutStatusGlyph(withoutTrailingBlanks(reported))
    guard let worktreePath, let relative = path(title, relativeTo: worktreePath, home: home)
    else { return title }
    return relative.isEmpty ? t("tab.shell") : relative
  }

  /// Gemini pads its title to 80 characters; a title of nothing but blanks stays.
  private static func withoutTrailingBlanks(_ title: String) -> String {
    let trimmed = title.withoutTrailingWhitespace
    return trimmed.isEmpty ? title : trimmed
  }

  private static func withoutStatusGlyph(_ title: String) -> String {
    guard let first = title.first, isStatusGlyph(first),
      title.dropFirst().first?.isWhitespace == true
    else { return title }
    return String(title.dropFirst().drop(while: \.isWhitespace))
  }

  private static func isStatusGlyph(_ character: Character) -> Bool {
    guard let scalar = character.unicodeScalars.first else { return false }
    return statusGlyphs.contains(scalar)
      || spinnerFrames.contains { $0.contains(scalar.value) }
  }

  /// A shell's directory title relative to the worktree, empty at its root, `nil` outside
  /// it. Shells write it whole, from `~`, or as `…/` and the last parts.
  private static func path(_ title: String, relativeTo worktree: String, home: String) -> String? {
    if let elided = title.removingPrefix(String.elidedPathStart) {
      return tail(elided.slashSeparatedParts, after: worktree)
    }
    for root in [worktree, worktree.abbreviatingHomeDirectory(home: home)] {
      if title == root { return "" }
      if let below = title.removingPrefix(root + "/") { return below }
    }
    return nil
  }

  /// What follows the worktree's own last parts in a title cut to its end,
  /// matching as many of them as the title still holds.
  private static func tail(_ shown: [Substring], after worktree: String) -> String? {
    let parts = worktree.slashSeparatedParts
    for count in stride(from: min(shown.count, parts.count), through: 1, by: -1)
    where parts.suffix(count).elementsEqual(shown.prefix(count)) {
      return shown.dropFirst(count).joined(separator: "/")
    }
    return nil
  }
}
