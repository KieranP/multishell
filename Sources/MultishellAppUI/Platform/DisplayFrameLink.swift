import AppKit

/// A display link on the main run loop in the common modes, so a frame held up
/// by a scroll or a resize counts as one; see `Platform.startDisplayFrameCallbacks`.
@MainActor
final class DisplayFrameLink: NSObject {
  private let onFrame: @MainActor (ContinuousClock.Instant) -> Void
  private var link: CADisplayLink?

  init(onFrame: @escaping @MainActor (ContinuousClock.Instant) -> Void) {
    self.onFrame = onFrame
  }

  /// A view's link follows its window to whichever display it is on; a
  /// screen's stays on that screen, and stops if it is unplugged.
  func start(following view: NSView?) {
    guard link == nil else { return }
    let selector = #selector(displayRefreshed)
    let link: CADisplayLink
    if let view, view.window != nil {
      link = view.displayLink(target: self, selector: selector)
    } else if let screen = NSScreen.main ?? NSScreen.screens.first {
      link = screen.displayLink(target: self, selector: selector)
    } else {
      return
    }
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  func stop() {
    link?.invalidate()
    link = nil
  }

  // When the main thread got to it, not the link's timestamp: the gap is
  // what a stall looks like.
  @objc private func displayRefreshed(_ link: CADisplayLink) {
    onFrame(.now)
  }
}
