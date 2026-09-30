import AppKit

extension NSButton {
  /// AppKit gives Escape to a button titled "Cancel" and to no other, so a
  /// translated title needs it set; see Docs/design/smaller-decisions.md.
  func takesEscape() {
    keyEquivalent = "\u{1b}"
  }
}
