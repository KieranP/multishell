import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct AbandonedTabDragTests {
  private let tab = TerminalTab.ID()

  @Test func aDragNothingTookEndsOnceTheButtonIsUp() {
    var drag = TabDragState()
    drag.begin(tab)
    let generation = drag.generation

    drag.endAbandoned(generation)

    #expect(!drag.isDragging)
  }

  @Test func aLaterDragOfTheSameTabOutlivesTheEarlierOnesRelease() {
    var drag = TabDragState()
    drag.begin(tab)
    let first = drag.generation
    drag.end()
    drag.begin(tab)

    drag.endAbandoned(first)

    #expect(drag.tabID == tab)
  }

  @Test func theWaitReturnsOnlyAfterTheButtonComesUp() async {
    let polls = LineRecorder()

    await DragRelease.wait(
      isPressed: {
        polls.record("poll")
        return polls.received.count < 3
      }, every: .milliseconds(1), grace: .zero)

    #expect(polls.received.count == 3)
  }
}
