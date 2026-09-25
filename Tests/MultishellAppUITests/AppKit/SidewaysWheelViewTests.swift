import SwiftUI
import Testing

@testable import MultishellAppUI

/// What a turn does to the strip is AppKit's behaviour rather than
/// arithmetic, so each is checked against a real scroller.
@Suite(.serialized) @MainActor
struct SidewaysWheelViewTests {
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
    let container = NSView(frame: frame)
    let scroller = NSScrollView(frame: frame)
    scroller.documentView = NSView(frame: CGRect(x: 0, y: 0, width: 1440, height: 28))
    scroller.hasHorizontalScroller = false
    let catcher = SidewaysWheelView(frame: frame)
    let reference = ScrollerReference()
    reference.scroller = scroller
    catcher.reference = reference
    container.addSubview(scroller)
    container.addSubview(catcher)
    return (OffscreenWindow.holding(container), scroller, catcher)
  }

  private func scrolled(_ scroller: NSScrollView) -> Double {
    Double(scroller.contentView.bounds.origin.x)
  }

  @Test func aVerticalTurnScrollsTheStripSideways() {
    let (window, scroller, catcher) = strip()
    catcher.scrollWheel(with: wheel(vertical: -40))
    OffscreenWindow.settle(until: { scrolled(scroller) > 0 }, within: 2)
    #expect(scrolled(scroller) > 0, "the strip moved along its tabs")
    withExtendedLifetime(window) {}
  }

  /// Why the catcher is there at all: the same event, handed to the scroller
  /// as it arrives, moves it by nothing.
  @Test func theSameTurnGivenStraightToTheScrollerMovesNothing() {
    let (window, scroller, _) = strip()
    scroller.scrollWheel(with: wheel(vertical: -40))
    OffscreenWindow.settle(within: 0.25)
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
    OffscreenWindow.settle(until: { scrolled(near) > 0 && scrolled(far) > 0 }, within: 2)
    OffscreenWindow.settle(within: 0.25)
    #expect(scrolled(far) > scrolled(near))
    withExtendedLifetime([nearWindow, farWindow]) {}
  }

  @Test func aDiagonalTurnMovesAsFarAsItsVerticalAlone() {
    let (straightWindow, straight, straightCatcher) = strip()
    let (diagonalWindow, diagonal, diagonalCatcher) = strip()
    straightCatcher.scrollWheel(with: wheel(vertical: -40))
    diagonalCatcher.scrollWheel(with: wheel(vertical: -40, horizontal: 30))
    OffscreenWindow.settle(until: { scrolled(straight) > 0 && scrolled(diagonal) > 0 }, within: 2)
    OffscreenWindow.settle(within: 0.25)
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
    OffscreenWindow.settle(until: { scrolled(turned) > 0 && scrolled(control) > 0 }, within: 2)
    OffscreenWindow.settle(within: 0.25)
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
    catcher.reference = ScrollerReference()
    catcher.scrollWheel(with: wheel(vertical: -40))
    OffscreenWindow.settle(within: 0.25)
    #expect(scrolled(scroller) == 0)
    withExtendedLifetime(window) {}
  }
}
