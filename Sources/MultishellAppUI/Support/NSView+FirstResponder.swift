import AppKit

extension NSView {
  var isFirstResponder: Bool { window?.firstResponder === self }

  /// AppKit is asked to look at menu enablement now, not at its next
  /// scheduled update.
  func takeFirstResponder() {
    guard let window, !isFirstResponder else { return }
    window.makeFirstResponder(self)
    NSApp.setWindowsNeedUpdate(true)
  }
}
