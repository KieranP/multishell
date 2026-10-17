/// A colour a theme's `terminal` section sets, written in the file as its raw
/// value. libghostty takes no alpha, so it drops one on all but the focus ring.
public enum TerminalColorKey: String, CaseIterable, Sendable {
  case background
  case cursor
  case cursorText = "cursor_text"
  case focusRing = "focus_ring"
  case foreground
  case searchBackground = "search_background"
  case searchForeground = "search_foreground"
  case searchSelectedBackground = "search_selected_background"
  case searchSelectedForeground = "search_selected_foreground"
  case selectionBackground = "selection_background"
  case selectionForeground = "selection_foreground"

  /// `""` sets no colour: no focus ring, and the cursor's and a selection's
  /// text left to libghostty, which keeps each cell's own.
  var takesNone: Bool {
    switch self {
    case .cursorText, .focusRing, .selectionForeground: true
    default: false
    }
  }
}
