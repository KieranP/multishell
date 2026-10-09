import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelStateClearingTests {
  @Test func clearingByHandDropsAStaleWorkingDot() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: deadPID())
    )
    harness.stateSource.send(
      SessionStateReport(
        state: .attention,
        workingDirectory: harness.feature.path.path,
        pid: deadPID(),
      )
    )

    harness.model.clearState(of: tab)
    #expect(harness.model.state(of: tab) == nil)
    harness.model.clearState(ofWorktree: harness.feature.id)
    #expect(harness.model.sessionStates.showsNothing)
    #expect(harness.model.pidWatch == nil)
  }
}
