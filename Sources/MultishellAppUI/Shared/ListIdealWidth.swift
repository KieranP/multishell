import AppKit
import SwiftUI

/// What a scrolled list's rows ask for laid out whole: its lazy stack draws only
/// the rows on screen, so an edge's fit lays every one out here.
@MainActor
enum ListIdealWidth {
  /// A scroller the user set to always show takes its width from the rows.
  private static var legacyScrollerWidth: Double {
    guard NSScroller.preferredScrollerStyle == .legacy else { return 0 }
    return NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
  }

  static func of(_ rows: some View) -> Double {
    let rowsWidth = NSHostingView(rootView: rows.fixedSize()).fittingSize.width
    return rowsWidth + legacyScrollerWidth
  }
}
