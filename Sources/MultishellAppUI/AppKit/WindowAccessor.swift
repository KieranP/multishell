import SwiftUI

/// Hands the enclosing `NSWindow` to whoever needs it, once the view is in
/// one. SwiftUI offers no other way to learn which window a scene became.
struct WindowAccessor: NSViewRepresentable {
  let onWindow: (NSWindow?) -> Void

  func makeNSView(context: Context) -> WindowAccessorView {
    let view = WindowAccessorView()
    view.onWindow = onWindow
    return view
  }

  func updateNSView(_ view: WindowAccessorView, context: Context) {}
}
