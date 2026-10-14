import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelFailedWorkerSweepTests {
  @Test func aKilledWorkersRowGoesOnceItsLingerIsOverAndNoTaskIsLeft() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    harness.model.failedWorkerLingering = 0.1
    let session = onlyPane.id
    func workers() -> [Worker] { harness.model.sessionStates.workers(.session(session)) }

    harness.messageSource.send(
      SessionStateReport(
        state: .running,
        sessionID: session,
        launched: WorkerReport(id: "a0", phase: .started),
      )
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session, killedTaskID: "a0")
    )
    #expect(workers().map(\.shownState) == [.failed])
    #expect(harness.model.failedWorkerSweep != nil)

    try await waitUntil({ workers().isEmpty }, seconds: 4)
    #expect(workers().isEmpty)
    #expect(harness.model.failedWorkerSweep == nil)
  }
}
