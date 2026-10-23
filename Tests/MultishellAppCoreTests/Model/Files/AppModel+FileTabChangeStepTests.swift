import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFileTabChangeStepTests {
  @Test func stepsAskedBeforeTheViewTakesOneAreEachTakenOnceInTurn() {
    let harness = Harness()
    let tabID = UUID()

    harness.model.stepToChange(.next, in: tabID)
    harness.model.stepToChange(.previous, in: tabID)

    #expect(harness.model.takeChangeStepRequests(tabID) == [.next, .previous])
    #expect(harness.model.takeChangeStepRequests(tabID).isEmpty)
  }

  @Test func takingWhenNoStepWasAskedRedrawsNothing() {
    let harness = Harness()
    let wrote = AtomicFlag()
    withObservationTracking {
      _ = harness.model.changeStepRequests
    } onChange: {
      wrote.raise()
    }

    _ = harness.model.takeChangeStepRequests(UUID())

    #expect(!wrote.raised)
  }

  @Test func aClosedTabsUntakenStepGoesWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    harness.model.stepToChange(.next, in: tab.id)
    harness.model.noteChangeSteps(ChangeSteps(hasNext: true, hasPrevious: false), of: tab.id)
    harness.model.noteSteppedChangeAnchor(
      ChangeAnchor(
        headDigest: 0,
        headLineAbove: 1,
        headLineBelow: nil,
        textAbove: nil,
        lineText: "a",
      ),
      of: tab.id,
    )

    harness.model.closeTab(tab.id)

    #expect(harness.model.changeStepRequests[tab.id] == nil)
    #expect(harness.model.fileTabChangeSteps[tab.id] == nil)
    #expect(harness.model.steppedChangeAnchor(of: tab.id) == nil)
  }

  @Test func aTabItsViewHasNotReportedOnOffersNoStepEitherWay() {
    let harness = Harness()
    let tabID = UUID()

    #expect(harness.model.changeSteps(of: tabID) == .neitherWay)

    harness.model.noteChangeSteps(ChangeSteps(hasNext: true, hasPrevious: false), of: tabID)

    #expect(harness.model.changeSteps(of: tabID).allows(.next))
  }
}
