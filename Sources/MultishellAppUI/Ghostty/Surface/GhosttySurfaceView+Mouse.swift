import AppKit
import GhosttyKit

/// The mouse as libghostty takes it: a position in points from the top left,
/// sent before every button so a click lands where the pointer is.
extension GhosttySurfaceView {
  override func mouseDown(with event: NSEvent) {
    // Taken here too, or a click leaves the Edit menu judging the old focus.
    takeFirstResponder()
    sendButton(GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, event)
  }

  override func mouseUp(with event: NSEvent) {
    sendButton(GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, event)
  }

  /// Unclaimed, a right click goes on to AppKit, which has no menu here.
  override func rightMouseDown(with event: NSEvent) {
    takeFirstResponder()
    if !sendButton(GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, event) {
      super.rightMouseDown(with: event)
    }
  }

  override func rightMouseUp(with event: NSEvent) {
    if !sendButton(GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, event) {
      super.rightMouseUp(with: event)
    }
  }

  override func otherMouseDown(with event: NSEvent) {
    takeFirstResponder()
    sendButton(GHOSTTY_MOUSE_PRESS, GhosttyMouseButton.button(forNumber: event.buttonNumber), event)
  }

  override func otherMouseUp(with event: NSEvent) {
    sendButton(
      GHOSTTY_MOUSE_RELEASE, GhosttyMouseButton.button(forNumber: event.buttonNumber), event)
  }

  override func mouseMoved(with event: NSEvent) { move(event) }
  override func mouseDragged(with event: NSEvent) { move(event) }
  override func rightMouseDragged(with event: NSEvent) { move(event) }
  override func otherMouseDragged(with event: NSEvent) { move(event) }
  override func mouseEntered(with event: NSEvent) { move(event) }

  /// Off the surface reads as -1, -1, which ends hover and link underlines.
  /// Not mid-drag, which goes on reporting outside the pane.
  override func mouseExited(with event: NSEvent) {
    guard let surface, NSEvent.pressedMouseButtons == 0 else { return }
    ghostty_surface_mouse_pos(surface, -1, -1, GhosttyModifiers.mods(event.modifierFlags))
  }

  /// Deltas as AppKit gives them, which is the speed panes have always
  /// scrolled at; libghostty's own `mouse-scroll-multiplier` scales them.
  override func scrollWheel(with event: NSEvent) {
    guard let surface else { return }
    let flags = GhosttyScrollFlags(event)
    ghostty_surface_mouse_scroll(
      surface, event.scrollingDeltaX, event.scrollingDeltaY, flags.rawValue)
  }

  @discardableResult
  private func sendButton(
    _ state: ghostty_input_mouse_state_e, _ button: ghostty_input_mouse_button_e, _ event: NSEvent
  ) -> Bool {
    guard let surface else { return false }
    move(event)
    return ghostty_surface_mouse_button(
      surface, state, button, GhosttyModifiers.mods(event.modifierFlags))
  }

  private func move(_ event: NSEvent) {
    guard let surface else { return }
    let point = convert(event.locationInWindow, from: nil)
    ghostty_surface_mouse_pos(
      surface, point.x, bounds.height - point.y, GhosttyModifiers.mods(event.modifierFlags))
  }
}
