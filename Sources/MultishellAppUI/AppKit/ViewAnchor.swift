import SwiftUI

/// Hands over an `NSView` filling the space it is laid in, for AppKit UI placed
/// against a SwiftUI view: a menu popped up below a button.
struct ViewAnchor: NSViewRepresentable {
  let onMake: (NSView) -> Void

  func makeNSView(context: Context) -> AccessibilityHiddenView {
    let view = AccessibilityHiddenView()
    onMake(view)
    return view
  }

  func updateNSView(_ view: AccessibilityHiddenView, context: Context) {}
}
