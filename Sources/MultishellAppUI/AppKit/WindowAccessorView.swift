import AppKit

final class WindowAccessorView: AccessibilityHiddenView {
  var onMoveToWindow: ((NSWindow?) -> Void)?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    onMoveToWindow?(window)
  }
}
