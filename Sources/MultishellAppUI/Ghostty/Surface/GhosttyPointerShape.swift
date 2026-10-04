import AppKit
import GhosttyKit

/// The pointer a program or libghostty asks for over a pane, after Ghostty's
/// own `setCursorShape`: an I-beam over text, a hand over a link.
enum GhosttyPointerShape {
  /// `nil` for a shape the Mac draws no cursor for; the current one stays.
  @MainActor
  static func cursor(for shape: ghostty_action_mouse_shape_e) -> NSCursor? {
    switch shape {
    case GHOSTTY_MOUSE_SHAPE_DEFAULT: .arrow
    case GHOSTTY_MOUSE_SHAPE_TEXT: .iBeam
    case GHOSTTY_MOUSE_SHAPE_VERTICAL_TEXT: .iBeamCursorForVerticalLayout
    case GHOSTTY_MOUSE_SHAPE_POINTER: .pointingHand
    case GHOSTTY_MOUSE_SHAPE_GRAB: .openHand
    case GHOSTTY_MOUSE_SHAPE_GRABBING: .closedHand
    case GHOSTTY_MOUSE_SHAPE_CROSSHAIR: .crosshair
    case GHOSTTY_MOUSE_SHAPE_CONTEXT_MENU: .contextualMenu
    case GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED: .operationNotAllowed
    case GHOSTTY_MOUSE_SHAPE_W_RESIZE, GHOSTTY_MOUSE_SHAPE_E_RESIZE, GHOSTTY_MOUSE_SHAPE_EW_RESIZE,
      GHOSTTY_MOUSE_SHAPE_COL_RESIZE:
      .resizeLeftRight
    case GHOSTTY_MOUSE_SHAPE_N_RESIZE, GHOSTTY_MOUSE_SHAPE_S_RESIZE, GHOSTTY_MOUSE_SHAPE_NS_RESIZE,
      GHOSTTY_MOUSE_SHAPE_ROW_RESIZE:
      .resizeUpDown
    default: nil
    }
  }
}
