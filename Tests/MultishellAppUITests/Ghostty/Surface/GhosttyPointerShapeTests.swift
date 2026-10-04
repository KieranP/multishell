import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttyPointerShapeTests {
  private static let shapes: [(ghostty_action_mouse_shape_e, NSCursor)] = [
    (GHOSTTY_MOUSE_SHAPE_DEFAULT, .arrow), (GHOSTTY_MOUSE_SHAPE_TEXT, .iBeam),
    (GHOSTTY_MOUSE_SHAPE_VERTICAL_TEXT, .iBeamCursorForVerticalLayout),
    (GHOSTTY_MOUSE_SHAPE_POINTER, .pointingHand), (GHOSTTY_MOUSE_SHAPE_GRAB, .openHand),
    (GHOSTTY_MOUSE_SHAPE_GRABBING, .closedHand), (GHOSTTY_MOUSE_SHAPE_CROSSHAIR, .crosshair),
    (GHOSTTY_MOUSE_SHAPE_CONTEXT_MENU, .contextualMenu),
    (GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED, .operationNotAllowed),
    (GHOSTTY_MOUSE_SHAPE_W_RESIZE, .resizeLeftRight),
    (GHOSTTY_MOUSE_SHAPE_E_RESIZE, .resizeLeftRight),
    (GHOSTTY_MOUSE_SHAPE_EW_RESIZE, .resizeLeftRight),
    (GHOSTTY_MOUSE_SHAPE_COL_RESIZE, .resizeLeftRight),
    (GHOSTTY_MOUSE_SHAPE_N_RESIZE, .resizeUpDown), (GHOSTTY_MOUSE_SHAPE_S_RESIZE, .resizeUpDown),
    (GHOSTTY_MOUSE_SHAPE_NS_RESIZE, .resizeUpDown),
    (GHOSTTY_MOUSE_SHAPE_ROW_RESIZE, .resizeUpDown),
  ]

  @Test func eachShapeTheMacHasACursorForGetsIt() {
    for (shape, cursor) in Self.shapes {
      #expect(GhosttyPointerShape.cursor(for: shape) == cursor, "shape \(shape.rawValue)")
    }
  }

  @Test func aShapeTheMacHasNoCursorForMapsToNone() {
    #expect(GhosttyPointerShape.cursor(for: GHOSTTY_MOUSE_SHAPE_WAIT) == nil)
  }
}
