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
  /// A sidebar row carrying a user's name over its branch. Two lines of
  /// text where `rowHeight` holds one, so the branch is not clipped.
  var namedRowHeight: Double { (body * 3.2).rounded() }

  /// How tall a worktree's row is. Asked here rather than worked out at
  /// each call site: the row draws itself this tall and the sidebar counts
  /// a project's block off it to place the drop indicator, and the two
  /// disagreeing puts the indicator in the wrong half.
  func worktreeRowHeight(isNamed: Bool, isRenaming: Bool) -> Double {
    isNamed || isRenaming ? namedRowHeight : rowHeight
  }

  var tabHeight: Double { (body * 2.6).rounded() }
  var indent: Double { (body * 2).rounded() }

  /// The sidebar and detail headers. The one size here that does not scale
  /// with the font, so it is a constant and sits apart from the rest.
  ///
  /// Not smaller: a window with a hidden title bar and a unified-compact
  /// toolbar keeps a 40 pt title-bar band at the top, and anything but the
  /// header that reaches into it (the tab strip, a surface) makes AppKit
  /// paint the band's backdrop over the header. Measured with
  /// `NSWindow.contentLayoutRect`; 32 without a toolbar, 52 for the
  /// unified style.
  static let headerHeight: Double = 40
}
