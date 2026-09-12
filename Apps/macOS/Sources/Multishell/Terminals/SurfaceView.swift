import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// Places one session's surface in the SwiftUI tree. The surface view
/// outlives any `SurfaceView`, so the process and scrollback survive.
struct SurfaceView: NSViewRepresentable {
  let model: AppModel
  let sessionID: TerminalSession.ID
  let isFocused: Bool
  /// Read so that a session opened after this view first drew, which
  /// changes nothing in the workspace, still triggers `updateNSView`.
  let isLive: Bool

  func makeNSView(context: Context) -> SurfaceFrame { SurfaceFrame() }

  func updateNSView(_ frame: SurfaceFrame, context: Context) {
    frame.acceptsDrop = { [model] in model.acceptsFileDrop(into: sessionID) }
    frame.receiveDrop = { [model] urls, focus in
      model.dropFiles(urls, into: sessionID, takingFocus: focus)
    }
    frame.show(model.surface(for: sessionID), focused: isFocused) { [model] in
      model.focusSurface(sessionID)
    }
  }
}

/// Focus cannot be given to a view not yet in a window, and a tab switch
/// attaches surfaces a pass late, so the frame remembers and acts later.
@MainActor
final class SurfaceFrame: NSView {
  var acceptsDrop: (() -> Bool)?
  var receiveDrop: (([URL], Bool) -> Bool)?
  private var requestFocus: (() -> Void)?
  private var wantsFocus = false
  private var surface: NSView?
  private var highlight: NSView?

  init() {
    super.init(frame: .zero)
    // Neither engine registers a dragged type, so a drop walks up to this
    // frame. Promises too, a drag with no file URL offering nothing else.
    registerForDraggedTypes([.fileURL] + PromisedDrop.draggedTypes)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// The surface, whether this pane has the keyboard and how to ask for it,
  /// in one call: a frame `ForEach` hands to another session must never
  /// focus with the closure or the flag of the one it held.
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
      addSubview(view, positioned: .below, relativeTo: highlight)
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

// MARK: - Files dropped on the terminal

extension SurfaceFrame {
  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard acceptsDrop?() == true, Self.hasFiles(sender) else { return [] }
    let operation = Self.operation(allowedBy: sender)
    guard !operation.isEmpty else { return [] }
    showHighlight()
    return operation
  }

  /// An operation the source offers, or the drop never happens. Any will do,
  /// only the path being read.
  private static func operation(allowedBy sender: any NSDraggingInfo) -> NSDragOperation {
    let allowed = sender.draggingSourceOperationMask
    for candidate: NSDragOperation in [.copy, .generic, .link] where allowed.contains(candidate) {
      return candidate
    }
    return []
  }

  /// Asked again as the drag hovers: the shell under the cursor can exit
  /// mid-drag, and the pane must stop offering a drop it would refuse.
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

  /// The drag's own path for the user's file, its promise for a copy only
  /// this app can read; see `PromisedDrop`.
  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    hideHighlight()
    let urls = Self.fileURLs(from: sender)
    let own = DroppedFiles.own(among: urls)
    let promises =
      DroppedFiles.needsPromise(for: urls) ? PromisedDrop.receivers(from: sender) : []
    // Held from here rather than read when the files land: this frame
    // outlives its session, and a changed pane tree would rebind it.
    let drop = receiveDrop
    guard !promises.isEmpty else {
      guard !urls.isEmpty else { return false }
      return drop?(urls, true) ?? false
    }
    // A drag of both kinds: the user's own go in now and the copies follow.
    // Two pastes, rather than losing the files nobody promised.
    if !own.isEmpty { _ = drop?(own, true) }
    PromisedDrop.receive(promises) { [weak self] urls in
      guard !urls.isEmpty else { return }
      // Focus only if this pane is still on screen: a slow copy must not
      // pull the user back to a tab they have left.
      _ = drop?(urls, self?.window != nil)
    }
    return true
  }

  /// Files only, a drag of text having no path to hand the terminal. The
  /// promise is asked about first, asking for a URL being what copies.
  private static func hasFiles(_ sender: any NSDraggingInfo) -> Bool {
    !PromisedDrop.receivers(from: sender).isEmpty || !fileURLs(from: sender).isEmpty
  }

  private static func fileURLs(from sender: any NSDraggingInfo) -> [URL] {
    sender.draggingPasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
  }

  /// Which pane a drop will land in, a split having several. A view over the
  /// surface, which paints over a border on this frame.
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
