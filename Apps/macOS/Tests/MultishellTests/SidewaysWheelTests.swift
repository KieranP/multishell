import AppKit
import SwiftUI
import Testing

@testable import Multishell

/// The two halves a scrolling tab strip wears: a marker inside the scroller
/// that says where it is, and a catcher outside that hands it the turns. A
/// mouse turns one way, and a horizontal scroller is handed nothing by a
/// vertical scroll, so what happens here is AppKit's behaviour rather than
/// arithmetic and is checked against a real scroller.
@Suite @MainActor
struct SidewaysWheelTests {
  private func wheel(vertical: Double, horizontal: Double = 0) -> NSEvent {
    let event = CGEvent(
      scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)!
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: vertical)
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: horizontal)
    return NSEvent(cgEvent: event)!
  }

  /// A strip's shape: tabs wider than the room they are seen through, with
  /// the catcher over the scroller rather than in it.
  private func strip() -> (NSWindow, NSScrollView, SidewaysWheelView) {
    let frame = CGRect(x: 0, y: 0, width: 300, height: 28)
    let window = NSWindow(
      contentRect: frame, styleMask: [.titled], backing: .buffered, defer: true)
    let container = NSView(frame: frame)
    let scroller = NSScrollView(frame: frame)
    scroller.documentView = NSView(frame: CGRect(x: 0, y: 0, width: 1440, height: 28))
    scroller.hasHorizontalScroller = false
    let catcher = SidewaysWheelView(frame: frame)
    let handle = ScrollerHandle()
    handle.scroller = scroller
    catcher.handle = handle
    container.addSubview(scroller)
    container.addSubview(catcher)
    window.contentView = container
    container.layoutSubtreeIfNeeded()
    return (window, scroller, catcher)
  }

  /// A scroller answers a wheel on its own schedule, so nothing is read back
  /// in the same turn it was sent.
  private func settle() {
    RunLoop.main.run(until: Date().addingTimeInterval(0.25))
  }

  private func scrolled(_ scroller: NSScrollView) -> Double {
    Double(scroller.contentView.bounds.origin.x)
  }

  @Test func aVerticalTurnScrollsTheStripSideways() {
    let (window, scroller, catcher) = strip()
    catcher.scrollWheel(with: wheel(vertical: -40))
    settle()
    #expect(scrolled(scroller) > 0, "the strip moved along its tabs")
    withExtendedLifetime(window) {}
  }

  /// Why the catcher is there at all: the same event, handed to the scroller
  /// as it arrives, moves it by nothing.
  @Test func theSameTurnGivenStraightToTheScrollerMovesNothing() {
    let (window, scroller, _) = strip()
    scroller.scrollWheel(with: wheel(vertical: -40))
    settle()
    #expect(scrolled(scroller) == 0)
    withExtendedLifetime(window) {}
  }

  /// In points, not tabs: stepping a whole tab a notch read as jumpy, and a
  /// turn twice as far has to move twice as far.
  @Test func aTurnMovesTheStripAsFarAsItWasTurned() {
    let (nearWindow, near, nearCatcher) = strip()
    let (farWindow, far, farCatcher) = strip()
    nearCatcher.scrollWheel(with: wheel(vertical: -40))
    farCatcher.scrollWheel(with: wheel(vertical: -80))
    settle()
    #expect(scrolled(far) > scrolled(near))
    withExtendedLifetime([nearWindow, farWindow]) {}
  }

  /// A sideways turn is the scroller's own, and a click, a drag or a drop is
  /// the tabs': the catcher answers for none of them.
  @Test func onlyAVerticalScrollIsTakenFromWhatIsUnderneath() {
    let (window, _, catcher) = strip()
    #expect(catcher.hitTest(NSPoint(x: 10, y: 10)) == nil, "no event at all")
    withExtendedLifetime(window) {}
  }

  @Test func aTurnWithNoScrollerToHandItToIsDropped() {
    let (window, scroller, catcher) = strip()
    catcher.handle = ScrollerHandle()
    catcher.scrollWheel(with: wheel(vertical: -40))
    settle()
    #expect(scrolled(scroller) == 0)
    withExtendedLifetime(window) {}
  }

  /// The regression, twice over. SwiftUI flattens a strip's view tree, so a
  /// catcher outside the scroller cannot find it by looking: looking climbed
  /// to the window and took the sidebar's, which is why the marker hands it
  /// over instead. And a catcher moved inside the scroller to fix that is
  /// hit-tested and then never called, a scroller taking every scroll over
  /// its own content first. The shape below is the workspace's: a sidebar
  /// that scrolls, then a strip in a GeometryReader with a gutter either
  /// side. Needs the window server SettingsPageSizeTests does; the window is
  /// never ordered in.
  @Test func theMarkedScrollerIsTheStripsAndTheCatcherStaysOutsideIt() {
    let handle = ScrollerHandle()
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
              .marksScroller(handle)
            }
            Color.clear.frame(width: 20)
          }
          .wheelScrollsSideways(handle)
        }
      }
      .frame(height: 28)
    }
    let host = NSHostingView(rootView: workspace)
    host.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
    let window = NSWindow(
      contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: true)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    settle()

    #expect(handle.scroller?.frame.height == 28, "the strip's, 28 high, not the sidebar's 400")
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
