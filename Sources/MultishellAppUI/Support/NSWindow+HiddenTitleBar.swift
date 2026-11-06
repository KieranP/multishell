import AppKit

extension NSWindow {
  /// The title bar's band handed to the content, its traffic lights kept,
  /// for a scene SwiftUI's `hiddenTitleBar` style does not reach: `Settings`.
  func hideTitleBar() {
    styleMask.insert(.fullSizeContentView)
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
  }
}
