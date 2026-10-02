import AppKit

/// `WindowAccessor`'s view, reporting each window it moves into.
final class WindowAccessorView: AccessibilityHiddenView {
  var onWindow: ((NSWindow?) -> Void)?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    onWindow?(window)
  }
}
