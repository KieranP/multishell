import Foundation
import MultishellCore

@testable import MultishellAppCore

@MainActor struct CopilotPaneHarness {
  static let copilot = AgentHookCatalogue.integration("copilot")!

  let harness = Harness()
  let tab: TerminalTab
  var session: TerminalSession.ID { tab.focusedSessionID }

  var state: SessionState? { harness.model.state(of: tab) }
  var workers: [String] { harness.model.sessionStates.workers(.session(session)).map(\.id) }

  init() {
    tab = harness.openBackgroundTab()
  }

  @discardableResult
  func hook(_ json: String) -> SessionStateReport? {
    guard let payload = AgentHookPayload(json: Data(json.utf8)),
      let report = Self.copilot.report(
        for: payload,
        sessionID: session,
        workingDirectory: nil,
        pid: nil,
      )
    else { return nil }
    harness.stateSource.send(report)
    return report
  }
}
