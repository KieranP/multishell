import SwiftUI

/// Hands the enclosing `NSWindow` to whoever needs it, once the view is in
/// one. SwiftUI offers no other way to learn which window a scene became.
struct WindowAccessor: NSViewRepresentable {
  let onMoveToWindow: (NSWindow?) -> Void

  func makeNSView(context: Context) -> WindowAccessorView {
    let view = WindowAccessorView()
    view.onMoveToWindow = onMoveToWindow
    return view
  }

  func updateNSView(_ view: WindowAccessorView, context: Context) {}
}
