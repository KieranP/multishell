import AppKit
import MultishellAppCore

extension SurfaceFrame {
  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard acceptsDrop?() == true, holdsFiles(sender) else { return [] }
    let operation = Self.operation(allowedBy: sender)
    guard !operation.isEmpty else { return [] }
    showDropHighlight()
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
    if operation.isEmpty { hideDropHighlight() }
    return operation
  }

  override func draggingExited(_ sender: (any NSDraggingInfo)?) {
    hideDropHighlight()
  }

  override func draggingEnded(_ sender: any NSDraggingInfo) {
    hideDropHighlight()
  }

  /// The drag's own path for the user's file, its promise for a copy only
  /// this app can read; see `PromisedDrop`.
  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    hideDropHighlight()
    let urls = Self.fileURLs(from: sender)
    let originals = PromisedDropCopies.originals(among: urls)
    let promises =
      PromisedDropCopies.needsPromise(for: urls) ? PromisedDrop.receivers(from: sender) : []
    // Held from here rather than read when the files land: this frame
    // outlives its session, and a changed pane tree would rebind it.
    let drop = receiveDrop
    guard !promises.isEmpty else {
      guard !urls.isEmpty else { return false }
      return drop?(urls, true) ?? false
    }
    // A drag of both kinds: the user's own go in now and the copies follow.
    // Two pastes, rather than losing the files nobody promised.
    if !originals.isEmpty { _ = drop?(originals, true) }
    PromisedDrop.receive(promises) { [weak self] urls in
      guard !urls.isEmpty else { return }
      // Focus only if this pane is still on screen: a slow copy must not
      // pull the user back to a tab they have left.
      _ = drop?(urls, self?.window != nil)
    }
    return true
  }

  private func holdsFiles(_ sender: any NSDraggingInfo) -> Bool {
    if let known = lastDragFileCheck, known.sequence == sender.draggingSequenceNumber {
      return known.hasFiles
    }
    let answer = Self.pasteboardHasFiles(sender)
    lastDragFileCheck = (sender.draggingSequenceNumber, answer)
    return answer
  }

  /// Files only, a drag of text having no path to hand the terminal. The
  /// promise is asked about first, asking for a URL being what copies.
  private static func pasteboardHasFiles(_ sender: any NSDraggingInfo) -> Bool {
    !PromisedDrop.receivers(from: sender).isEmpty || !fileURLs(from: sender).isEmpty
  }

  private static func fileURLs(from sender: any NSDraggingInfo) -> [URL] {
    sender.draggingPasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
  }

  /// Which pane a drop will land in, a split having several. A view over the
  /// surface, which paints over a border on this frame.
  private func showDropHighlight() {
    guard dropHighlight == nil else { return }
    let view = NSView(frame: bounds)
    view.autoresizingMask = [.width, .height]
    view.wantsLayer = true
    view.layer?.borderWidth = 2
    view.layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
    addSubview(view)
    dropHighlight = view
  }

  private func hideDropHighlight() {
    dropHighlight?.removeFromSuperview()
    dropHighlight = nil
  }
}
