import AppKit
import GhosttyKit

extension GhosttySurfaceView {
  /// Dropped once freed: a report queued from another thread can land after.
  /// The pointer and secure input are the view's own to answer; the rest go to the host.
  func receive(_ event: GhosttySurfaceEvent) {
    guard surface != nil else { return }
    switch event {
    case .retitled(let title):
      onRetitle?(title)

    case .bell:
      onBell?()

    case .commandFinished(let exitCode):
      onCommandFinish?(exitCode)

    case .pointerShape(let shape):
      guard let cursor = GhosttyPointerShape.cursor(for: shape) else { return }
      pointer = cursor
      window?.invalidateCursorRects(for: self)

    case .pointerVisible(let visible):
      NSCursor.setHiddenUntilMouseMoves(!visible)

    case .secureInput(let mode):
      wantsSecureInput = GhosttySecureInput.wantsSecureInput(after: mode, was: wantsSecureInput)
      syncSecureInput(hasKeyboard: hasKeyboard)
    }
  }

  /// Asked of libghostty, not read off the callback's flag, which says whether
  /// Ghostty would confirm the close rather than whether the process is there.
  func surfaceDidClose() {
    guard let surface else { return }
    if ghostty_surface_process_exited(surface) { onExit?() } else { onCloseRequest?() }
  }
}
