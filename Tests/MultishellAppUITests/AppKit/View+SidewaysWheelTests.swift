import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite(.serialized) @MainActor
struct ViewSidewaysWheelTests {
  /// The workspace's shape: a sidebar that scrolls beside a strip that does.
  /// Needs the window server AppSettingsWindowTests does.
  @Test func theMarkedScrollerIsTheStripsAndTheCatcherStaysOutsideIt() {
    let reference = ScrollerReference()
    let workspace = HStack(spacing: 0) {
      ScrollView { VStack { ForEach(0..<40, id: \.self) { row in Text("row \(row)") } } }
        .frame(width: 100)
      GeometryReader { _ in
        ScrollViewReader { _ in
          HStack(spacing: 0) {
            Color.clear.frame(width: 20)
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { tab in
                  Color.clear.frame(width: 120, height: 28).id(tab)
                }
              }
              .marksScroller(reference)
            }
            Color.clear.frame(width: 20)
          }
          .wheelScrollsSideways(reference)
        }
      }
      .frame(height: 28)
    }
    let host = NSHostingView(rootView: workspace)
    host.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
    let window = OffscreenWindow.holding(host)
    OffscreenWindow.settle(within: 0.25)

    #expect(reference.scroller?.frame.height == 28, "the strip's, 28 high, not the sidebar's 400")
    let catcher = firstCatcher(in: host)
    #expect(catcher != nil, "the catcher is in the hierarchy")
    #expect(catcher?.enclosingScrollView == nil, "and outside the scroller, or it is never called")
    withExtendedLifetime(window) {}
  }

  private func firstCatcher(in view: NSView) -> SidewaysWheelView? {
    if let found = view as? SidewaysWheelView { return found }
    for subview in view.subviews {
      if let found = firstCatcher(in: subview) { return found }
    }
    return nil
  }
}
