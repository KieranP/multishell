import AppKit

/// What takes the keyboard for a file tab drawing no text, an image or a
/// notice, so a click there focuses its tab and group as a text view's does.
final class FileTabFocusTargetView: NSView {
  var onFocus: () -> Void = {}

  override var acceptsFirstResponder: Bool { true }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
  }

  override func becomeFirstResponder() -> Bool {
    guard super.becomeFirstResponder() else { return false }
    onFocus()
    return true
  }
}
