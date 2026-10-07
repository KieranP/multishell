import AppKit
import GhosttyKit

extension GhosttySurfaceView {
  /// libghostty draws a hollow cursor unless the pane also has a key window.
  var hasKeyboard: Bool { isFirstResponder && window?.isKeyWindow == true }

  /// A click on this pane that only brought its window forward: the keyboard
  /// comes here too, and the click carries on. `GhosttyPaneEventMonitor` hit-tests.
  func focusOnActivatingClick(_ event: NSEvent) {
    guard let window, event.window === window, !window.isKeyWindow || !NSApp.isActive,
      !isFirstResponder
    else { return }
    takeFirstResponder()
  }

  /// AppKit names the new responder only after this returns, so the
  /// window's own answer would still be the old one.
  override func becomeFirstResponder() -> Bool {
    let became = super.becomeFirstResponder()
    guard became else { return false }
    setSurfaceFocus(window?.isKeyWindow == true)
    onFocus?()
    return true
  }

  override func resignFirstResponder() -> Bool {
    let resigned = super.resignFirstResponder()
    if resigned { setSurfaceFocus(false) }
    return resigned
  }

  func windowKeyDidChange() {
    setSurfaceFocus(hasKeyboard)
    if hasKeyboard { onFocus?() }
  }

  /// AppKit resigns nothing for a view taken out of its window, and libghostty
  /// starts every surface focused, so the move itself says which it is.
  func updateFocus() {
    setSurfaceFocus(hasKeyboard)
  }

  private func setSurfaceFocus(_ focused: Bool) {
    guard let surface else { return }
    ghostty_surface_set_focus(surface, focused)
    syncSecureInput(hasKeyboard: focused)
  }
}
