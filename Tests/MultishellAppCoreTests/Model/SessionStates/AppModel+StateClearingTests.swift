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
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: deadPID())
    )
    harness.messageSource.send(
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

  @Test func clearingOnePaneByHandEndsAProgramsHoldSoItsHooksMoveTheDotAgain() {
    let (harness, session) = Harness.withOnePane()
    harness.engine.delegate?.terminalHost(
      harness.engine,
      didReceive: ProgramStatus(state: .working, app: "claude-code"),
      from: nil,
      in: session.id,
    )

    harness.model.clearState(ofPane: session.id)
    harness.messageSource.send(SessionStateReport(state: .attention, sessionID: session.id))

    #expect(harness.model.sessionStates[.session(session.id)] == .attention)
  }
}
