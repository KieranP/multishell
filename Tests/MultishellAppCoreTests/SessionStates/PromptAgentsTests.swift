import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct PromptAgentsTests {
  private let session = TerminalSession(
    worktreeID: "/w",
    workingDirectory: URL(fileURLWithPath: "/w"),
    title: "Agent",
    agentID: "gemini",
  )

  @Test func aReportOutranksTheTypedAgentWhichOutranksTheTabsOwn() {
    let reported = ReportedAgent.reported("claude", pid: nil, after: nil)

    let all = PromptAgents(
      states: SessionStates(),
      reported: [session.id: reported],
      typed: [session.id: "codex"],
    )
    let typed = PromptAgents(states: SessionStates(), reported: [:], typed: [session.id: "codex"])
    let none = PromptAgents(states: SessionStates(), reported: [:], typed: [:])

    #expect(all.agentID(of: session) == "claude")
    #expect(typed.agentID(of: session) == "codex")
    #expect(none.agentID(of: session) == "gemini")
  }
}
