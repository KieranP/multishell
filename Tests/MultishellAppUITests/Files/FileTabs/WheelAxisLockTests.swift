import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct WheelAxisLockTests {
  @Test func aSidewaysGestureStaysSidewaysThoughSomeOfItsFramesLeanVertical() {
    var lock = WheelAxisLock()

    let began = lock.isVertical(dx: 6, dy: 1, phase: .began, momentumPhase: [])
    let leaning = lock.isVertical(dx: 1, dy: 3, phase: .changed, momentumPhase: [])
    let momentum = lock.isVertical(dx: 0, dy: 2, phase: [], momentumPhase: .changed)

    #expect([began, leaning, momentum] == [false, false, false])
  }

  @Test func theNextGestureChoosesItsAxisAfresh() {
    var lock = WheelAxisLock()
    _ = lock.isVertical(dx: 6, dy: 0, phase: .began, momentumPhase: [])
    let next = lock.isVertical(dx: 0, dy: 5, phase: .began, momentumPhase: [])

    #expect(next)
  }

  @Test func aMouseWheelWithoutPhasesChoosesEachClick() {
    var lock = WheelAxisLock()

    let sideways = lock.isVertical(dx: 4, dy: 0, phase: [], momentumPhase: [])
    let vertical = lock.isVertical(dx: 0, dy: 4, phase: [], momentumPhase: [])

    #expect(!sideways && vertical)
  }
}
