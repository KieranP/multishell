import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSessionStatesTests {
  @Test func clearingByHandDropsAStaleWorkingDot() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: 99999))
    h.source.send(SessionStateReport(state: .attention, cwd: h.feature.path.path, pid: 99998))

    h.model.clearState(of: tab)
    #expect(h.model.state(of: tab) == nil)
    h.model.clearState(ofWorktree: h.feature.id)
    #expect(h.model.sessionStates.isEmpty)
    #expect(h.model.pidWatch == nil)
  }
}
