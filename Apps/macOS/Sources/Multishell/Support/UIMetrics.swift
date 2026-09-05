import Foundation

/// Every chrome size, derived from one number so the UI font slider scales
/// the sidebar, tabs and header together and rows never clip their text.
struct UIMetrics {
  let body: Double

  init(fontSize: Double) {
    body = fontSize
  }

  var secondary: Double { body - 1 }
  var caption: Double { body - 2 }
  var badge: Double { body - 3 }
  var mono: Double { body - 1 }
  var icon: Double { body - 2 }

  var rowHeight: Double { (body * 2.15).rounded() }

  /// The sidebar and detail headers. Not smaller: a window with a hidden
  /// title bar and a unified-compact toolbar keeps a 40 pt title-bar band at
  /// the top, and anything but the header that reaches into it (the tab
  /// strip, a surface) makes AppKit paint the band's backdrop over the
  /// header. Measured with `NSWindow.contentLayoutRect`; 32 without a
  /// toolbar, 52 for the unified style.
  static let headerHeight: Double = 40
  var tabHeight: Double { (body * 2.6).rounded() }
  var indent: Double { (body * 2).rounded() }
}
