import AppKit
import MultishellCore
import SwiftUI

/// Places one session's surface in the SwiftUI tree.
///
/// The surface view outlives any `SurfaceView`: switching tabs tears this
/// representable down and a later one adopts the same NSView, so the process
/// and scrollback survive.
struct SurfaceView: NSViewRepresentable {
  let host: any TerminalSurfaceHost
  let sessionID: TerminalSession.ID
  let isFocused: Bool
  /// Read so that a session opened after this view first drew, which
  /// changes nothing in the workspace, still triggers `updateNSView`.
  let isLive: Bool

  func makeNSView(context: Context) -> SurfaceFrame { SurfaceFrame() }

  func updateNSView(_ frame: SurfaceFrame, context: Context) {
    frame.adopt(host.view(for: sessionID))
    frame.requestFocus = { [host] in host.focus(sessionID) }
    frame.wantsFocus = isFocused
  }
}

/// Focus cannot be given to a view that is not yet in a window, and after a
/// tab switch the new surfaces are attached a layout pass later than the
/// store changes. So the frame remembers that it should be focused and acts
/// when it lands in a window.
@MainActor
final class SurfaceFrame: NSView {
  var requestFocus: (() -> Void)?
  var wantsFocus = false { didSet { focusIfReady() } }

  private var surface: NSView?

  func adopt(_ view: NSView?) {
    guard surface !== view else { return }
    // Only detach a surface this frame still holds. When panes collapse,
    // SwiftUI can hand a sibling's surface to this frame before the sibling
    // is torn down, and that surface may already have a new parent.
    if let old = surface, old.superview === self {
      old.removeFromSuperview()
    }
    surface = view
    if let view {
      view.frame = bounds
      view.autoresizingMask = [.width, .height]
      addSubview(view)
    }
    focusIfReady()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    focusIfReady()
  }

  private func focusIfReady() {
    guard wantsFocus, window != nil, surface != nil else { return }
    requestFocus?()
  }
}
