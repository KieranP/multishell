import AppKit

extension NSScreen {
  /// The main screen's scale, for drawing before a view has a window to ask;
  /// 2 with no screen.
  @MainActor static var mainBackingScale: CGFloat { main?.backingScaleFactor ?? 2 }
}
