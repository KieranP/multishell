import AppKit

extension NSView {
  /// Takes first responder in this view's window, if it is in one and is not
  /// the responder already.
  ///
  /// Menu enablement follows the first responder, so AppKit is asked to look
  /// again now rather than at its next scheduled update; without that the
  /// Edit menu stays as it was until something else moves focus.
  func takeFirstResponder() {
    guard let window, window.firstResponder !== self else { return }
    window.makeFirstResponder(self)
    NSApp.setWindowsNeedUpdate(true)
  }
}
