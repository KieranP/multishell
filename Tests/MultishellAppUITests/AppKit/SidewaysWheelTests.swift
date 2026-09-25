import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI

/// What a turn does to the strip is AppKit's behaviour rather than
/// arithmetic, so each is checked against a real scroller.
@Suite(.serialized) @MainActor
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

  /// A scroller answers a wheel on its own schedule. `run(until:)` returns at
  /// once while the main run loop has no source, so the wait is looped.
  private func settle(until done: () -> Bool = { false }, within limit: TimeInterval = 0.25) {
    let deadline = Date().addingTimeInterval(limit)
    while !done(), Date() < deadline {
      RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
  }

  private func scrolled(_ scroller: NSScrollView) -> Double {
    Double(scroller.contentView.bounds.origin.x)
  }

  @Test func aVerticalTurnScrollsTheStripSideways() {
    let (window, scroller, catcher) = strip()
    catcher.scrollWheel(with: wheel(vertical: -40))
    settle(until: { scrolled(scroller) > 0 }, within: 2)
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
    settle(until: { scrolled(near) > 0 && scrolled(far) > 0 }, within: 2)
    settle()
    #expect(scrolled(far) > scrolled(near))
    withExtendedLifetime([nearWindow, farWindow]) {}
  }

  @Test func aDiagonalTurnMovesAsFarAsItsVerticalAlone() {
    let (straightWindow, straight, straightCatcher) = strip()
    let (diagonalWindow, diagonal, diagonalCatcher) = strip()
    straightCatcher.scrollWheel(with: wheel(vertical: -40))
    diagonalCatcher.scrollWheel(with: wheel(vertical: -40, horizontal: 30))
    settle(until: { scrolled(straight) > 0 && scrolled(diagonal) > 0 }, within: 2)
    settle()
    #expect(scrolled(straight) > 0)
    #expect(scrolled(diagonal) == scrolled(straight))
    withExtendedLifetime([straightWindow, diagonalWindow]) {}
  }

  /// The three delta fields of an axis are coupled: writing lines derives
  /// fixed, so adding to fixed afterwards counted the turn twice.
  @Test func aNotchOfAPlainWheelIsNotCountedTwice() {
    let (turnedWindow, turned, catcher) = strip()
    let (controlWindow, control, _) = strip()
    catcher.scrollWheel(with: notch(vertical: -3))
    control.scrollWheel(with: notch(horizontal: -3))
    settle(until: { scrolled(turned) > 0 && scrolled(control) > 0 }, within: 2)
    settle()
    #expect(scrolled(turned) > 0)
    #expect(scrolled(turned) == scrolled(control))
    withExtendedLifetime([turnedWindow, controlWindow]) {}
  }

  private func notch(vertical: Int32 = 0, horizontal: Int32 = 0) -> NSEvent {
    let event = CGEvent(
      scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: vertical,
      wheel2: horizontal, wheel3: 0)!
    return NSEvent(cgEvent: event)!
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

  /// The workspace's shape: a sidebar that scrolls beside a strip that does.
  /// Needs the window server SettingsPageSizeTests does.
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
