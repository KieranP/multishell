import AppKit
import MultishellCore
import SwiftUI

/// Places one session's surface in the SwiftUI tree.
///
/// The surface view outlives any `SurfaceView`: switching tabs tears this
/// representable down and a later one adopts the same NSView, so the process
/// and scrollback survive.
struct SurfaceView: NSViewRepresentable {
  let model: AppModel
  let sessionID: TerminalSession.ID
  let isFocused: Bool
  /// Read so that a session opened after this view first drew, which
  /// changes nothing in the workspace, still triggers `updateNSView`.
  let isLive: Bool

  func makeNSView(context: Context) -> SurfaceFrame { SurfaceFrame() }

  func updateNSView(_ frame: SurfaceFrame, context: Context) {
    frame.adopt(model.surface(for: sessionID))
    frame.requestFocus = { [model] in model.focusSurface(sessionID) }
    frame.acceptsDrop = { [model] in model.acceptsFileDrop(into: sessionID) }
    frame.receiveDrop = { [model] urls in model.dropFiles(urls, into: sessionID) }
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
  var acceptsDrop: (() -> Bool)?
  var receiveDrop: (([URL]) -> Bool)?
  var wantsFocus = false { didSet { focusIfReady() } }

  private var surface: NSView?
  private var highlight: NSView?

  init() {
    super.init(frame: .zero)
    // Neither engine registers a dragged type, so a drop that lands in a
    // surface walks up to this frame, whichever engine drew it.
    registerForDraggedTypes([.fileURL])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

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
      // Under any drop highlight: a surface adopted while a drag hovers
      // would otherwise be drawn over it, and every model change, this
      // drop's own focus included, runs an update.
      addSubview(view, positioned: .below, relativeTo: highlight)
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

// MARK: - Files dropped on the terminal

extension SurfaceFrame {
  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard acceptsDrop?() == true, !Self.fileURLs(from: sender).isEmpty else { return [] }
    let operation = Self.operation(allowedBy: sender)
    guard !operation.isEmpty else { return [] }
    showHighlight()
    return operation
  }

  /// An operation the source offers, or the drop never happens: not every
  /// app that drags a file offers `.copy`. Any of them will do, since only
  /// the path is read and the file itself is left alone.
  private static func operation(allowedBy sender: any NSDraggingInfo) -> NSDragOperation {
    let allowed = sender.draggingSourceOperationMask
    for candidate: NSDragOperation in [.copy, .generic, .link] where allowed.contains(candidate) {
      return candidate
    }
    return []
  }

  /// Asked again as the drag hovers, periodic updates included: the shell
  /// under the cursor can exit mid-drag, and the pane must stop offering a
  /// drop it would then refuse.
  override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
    let operation = draggingEntered(sender)
    if operation.isEmpty { hideHighlight() }
    return operation
  }

  override func draggingExited(_ sender: (any NSDraggingInfo)?) {
    hideHighlight()
  }

  override func draggingEnded(_ sender: any NSDraggingInfo) {
    hideHighlight()
  }

  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    hideHighlight()
    let urls = Self.fileURLs(from: sender)
    guard !urls.isEmpty else { return false }
    return receiveDrop?(urls) ?? false
  }

  /// Files only. A drag of text or of something promised but not yet on
  /// disk has no path to hand the terminal, so it is not offered a drop.
  private static func fileURLs(from sender: any NSDraggingInfo) -> [URL] {
    sender.draggingPasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
  }

  /// Which pane a drop will land in: a split has several, and the cursor is
  /// the only other clue. A view over the surface rather than a border on
  /// this frame, which the surface paints over in full.
  private func showHighlight() {
    guard highlight == nil else { return }
    let view = NSView(frame: bounds)
    view.autoresizingMask = [.width, .height]
    view.wantsLayer = true
    view.layer?.borderWidth = 2
    view.layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
    addSubview(view)
    highlight = view
  }

  private func hideHighlight() {
    highlight?.removeFromSuperview()
    highlight = nil
  }
}
