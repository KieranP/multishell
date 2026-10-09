import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelFailedWorkerSweepTests {
  @Test func aKilledWorkersRowGoesOnceItsLingerIsOverAndNoTaskIsLeft() async throws {
    let harness = Harness()
    harness.model.failedWorkerLingering = 0.1
    harness.model.select(harness.main)
    let session = harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID
    func workers() -> [Worker] { harness.model.sessionStates.workers(.session(session)) }

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: session,
        launched: WorkerReport(id: "a0", phase: .started),
      )
    )
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session, killedTaskID: "a0")
    )
    #expect(workers().map(\.shownState) == [.failed])
    #expect(harness.model.failedWorkerSweep != nil)

    try await waitUntil({ workers().isEmpty }, seconds: 4)
    #expect(workers().isEmpty)
    #expect(harness.model.failedWorkerSweep == nil)
  }
}
