import AppKit

extension NSView {
  /// Takes first responder in this view's window. AppKit is asked to look at
  /// menu enablement now, not at its next scheduled update.
  func takeFirstResponder() {
    guard let window, window.firstResponder !== self else { return }
    window.makeFirstResponder(self)
    NSApp.setWindowsNeedUpdate(true)
  }
}
