import AppKit

/// Focus cannot be given to a view not yet in a window, and a tab switch
/// attaches surfaces a pass late, so the frame remembers and acts later.
@MainActor
final class SurfaceFrame: NSView {
  var acceptsDrop: (() -> Bool)?
  var receiveDrop: (([URL], Bool) -> Bool)?
  private var requestFocus: (() -> Void)?
  private var wantsFocus = false
  private var surface: NSView?
  var dropHighlight: NSView?
  /// Whether this drag holds files, asked once per drag rather than once per
  /// mouse move: each ask reads the pasteboard.
  var filesInDrag: (sequence: Int, hasFiles: Bool)?

  init() {
    super.init(frame: .zero)
    // The engine registers no dragged type, so a drop walks up to this
    // frame. Promises too, a drag with no file URL offering nothing else.
    registerForDraggedTypes([.fileURL] + PromisedDrop.draggedTypes)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// All three in one call: a frame handed to another session must never
  /// focus with the closure or flag of the one it held.
  func show(_ view: NSView?, focused: Bool, requestFocus: @escaping () -> Void) {
    self.requestFocus = requestFocus
    let adopted = surface !== view
    // Taking first responder on every pass pulls focus out of whatever the
    // user is typing in, so only a new surface or a new claim asks.
    let claimed = focused && !wantsFocus
    wantsFocus = focused
    adopt(view)
    if adopted || claimed { focusIfReady() }
  }

  private func adopt(_ view: NSView?) {
    guard surface !== view else { return }
    // Only detach a surface this frame still holds: collapsing panes can
    // hand a sibling's over before the sibling is torn down.
    if let old = surface, old.superview === self {
      old.removeFromSuperview()
    }
    surface = view
    if let view {
      view.frame = bounds
      view.autoresizingMask = [.width, .height]
      // Under any drop highlight, a surface adopted mid-drag otherwise
      // drawing over it.
      addSubview(view, positioned: .below, relativeTo: dropHighlight)
    }
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
