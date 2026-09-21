import SwiftUI

extension KeyboardShortcut {
  /// Return on a dialog's lead button. `.defaultAction` repaints a
  /// destructive button blue; see Docs/design/smaller-decisions.md.
  static let dialogDefault = Self(.return, modifiers: [])
}
