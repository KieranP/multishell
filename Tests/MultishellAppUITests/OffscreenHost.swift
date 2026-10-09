import SwiftUI

/// A view hosted at a fixed width in a window never ordered in, read while the
/// window lives: hosted without one the same view measures a few points taller.
@MainActor
enum OffscreenHost {
  static func read<Content: View, Result>(
    _ content: Content,
    atWidth width: CGFloat,
    windowSize: CGSize,
    sizingOptions: NSHostingSizingOptions = .standardBounds,
    _ read: (NSView) -> Result,
  ) -> Result {
    let host = NSHostingView(rootView: content.frame(width: width))
    host.sizingOptions = sizingOptions
    let window = OffscreenWindow.holding(
      host,
      rect: NSRect(origin: .zero, size: windowSize),
      deferred: false,
    )
    return withExtendedLifetime(window) { read(host) }
  }
}
