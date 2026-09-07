import AppKit
import MultishellAppCore
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
    frame.receiveDrop = { [model] urls, focus in
      model.dropFiles(urls, into: sessionID, takingFocus: focus)
    }
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
  var receiveDrop: (([URL], Bool) -> Bool)?
  var wantsFocus = false { didSet { focusIfReady() } }

  private var surface: NSView?
  private var highlight: NSView?

  init() {
    super.init(frame: .zero)
    // Neither engine registers a dragged type, so a drop that lands in a
    // surface walks up to this frame, whichever engine drew it. Promises are
    // registered too, or a drag whose files are not written yet — which
    // offers no file URL at all — would be offered no drop.
    registerForDraggedTypes([.fileURL] + PromisedDrop.draggedTypes)
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
    guard acceptsDrop?() == true, Self.hasFiles(sender) else { return [] }
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

  /// The path a drag offers is used when the file is the user's own, and its
  /// promise asked for when the path is a copy this app alone can read, which
  /// is what a screenshot's preview offers (see `PromisedDrop`). That way
  /// round because a copy is not the file: an agent told to edit one edits
  /// something swept in a week, while the user's file goes untouched. A drag
  /// offering nothing but an unreadable path and no promise is still pasted,
  /// there being nothing better to say.
  ///
  /// The copies take a moment to arrive, so a promised drag is answered
  /// before its paste has happened: the one drop that cannot be refused back
  /// to the drag when no pty takes it.
  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    hideHighlight()
    let urls = Self.fileURLs(from: sender)
    let own = DroppedFiles.own(among: urls)
    let promises =
      DroppedFiles.needsPromise(for: urls) ? PromisedDrop.receivers(from: sender) : []
    // Held from here rather than read again when the files land: this frame
    // outlives the session it shows, and a pane tree that changed in between
    // would have rebound it to another one. The drop belongs to the pane it
    // was made on.
    let drop = receiveDrop
    guard !promises.isEmpty else {
      guard !urls.isEmpty else { return false }
      return drop?(urls, true) ?? false
    }
    // A drag of both kinds at once: what the user has goes in now, and the
    // copies follow when they arrive. Two pastes rather than one, which is
    // better than the files nobody promised going missing.
    if !own.isEmpty { _ = drop?(own, true) }
    PromisedDrop.receive(promises) { [weak self] urls in
      guard !urls.isEmpty else { return }
      // Focus only if this pane is still on screen. A copy that took its
      // time must not pull the user back to a tab they have since left,
      // which taking focus would do and would save.
      _ = drop?(urls, self?.window != nil)
    }
    return true
  }

  /// Files only. A drag of text, or of an image no app has made a file of,
  /// has no path to hand the terminal, so it is not offered a drop.
  ///
  /// The promise is asked about first because asking for a promised drag's
  /// file URL is what has macOS write the copy this app is meant to read, and
  /// a hover over a pane is no reason to copy a file that may never be
  /// dropped. Which of the two a drop then uses is decided when it lands.
  private static func hasFiles(_ sender: any NSDraggingInfo) -> Bool {
    !PromisedDrop.receivers(from: sender).isEmpty || !fileURLs(from: sender).isEmpty
  }

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
