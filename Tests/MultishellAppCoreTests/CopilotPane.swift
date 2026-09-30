import Foundation
import MultishellCore

@testable import MultishellAppCore

@MainActor struct CopilotPane {
  let h = Harness()
  let tab: TerminalTab
  var session: TerminalSession.ID { tab.focusedSessionID }

  init() {
    h.model.select(h.main)
    tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
  }

  @discardableResult
  func hook(_ json: String) -> SessionStateReport? {
    guard let payload = AgentHookPayload(json: Data(json.utf8)),
      let report = CopilotPayload.copilot.report(
        for: payload, sessionID: session, cwd: nil, pid: nil)
    else { return nil }
    h.stateSource.send(report)
    return report
  }

  var state: SessionState? { h.model.state(of: tab) }
  var workers: [String] { h.model.sessionStates.subagents(.session(session)).map(\.id) }
}
