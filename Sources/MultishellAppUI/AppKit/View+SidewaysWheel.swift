import SwiftUI

extension View {
  /// Goes on the content inside the scroller, which is the only place its
  /// own scroller can be named from.
  func marksScroller(_ reference: ScrollerReference) -> some View {
    background { ScrollerMarker(reference: reference) }
  }

  /// Turns a wheel's vertical scrolling sideways for the marked scroller. Goes
  /// outside the scroller, over it; see Docs/design/tabs-and-groups.md.
  func wheelScrollsSideways(_ reference: ScrollerReference) -> some View {
    overlay { SidewaysWheelCatcher(reference: reference) }
  }
}
