import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelAgentIDAtThePromptTests {
  /// The strip and the sidebar draw a mark from this, so a shell someone
  /// typed `claude` into has to stop looking like a shell.
  @Test func theMarkFollowsWhoIsAtThePromptRatherThanWhatOpenedTheTab() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    let tab = harness.store.workspace.tabs[0]

    #expect(model.agentIDAtThePrompt(of: tab) == nil, "a plain shell")
    #expect(model.agentIDAtThePrompt(of: session) == nil)

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "codex"))
    #expect(model.agentIDAtThePrompt(of: tab) == "codex")
    #expect(model.agentIDAtThePrompt(of: session) == "codex")
  }

  /// Typed at a prompt, with none of that agent's hooks installed: the
  /// shell's own report of what it just started is all the app has.
  @Test func aCommandThatIsAnAgentMarksThePaneUntilItFinishes() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    #expect(model.agentIDAtThePrompt(of: session) == "codex")
    #expect(model.agentBoardCards[0].occupant == .agent(id: "codex", name: "Codex"))

    harness.stateSource.send(
      SessionStateReport(state: .done, sessionID: session.id, isFromShellIntegration: true))
    #expect(model.agentIDAtThePrompt(of: session) == nil, "it exited, so the pane is a shell again")
  }

  /// A shell reports every command it starts and names only the agents, so
  /// the next unnamed one is the last agent's end whether a finish landed.
  @Test func aPlainCommandAfterAnAgentTakesTheMarkBack() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    #expect(model.agentIDAtThePrompt(of: session) == "codex")

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, isFromShellIntegration: true))
    #expect(model.agentIDAtThePrompt(of: session) == nil, "`ls` is not codex")
  }

  /// `multishell state` is documented for the user's own scripts, and one
  /// run from inside an agent's turn is not that agent's shell exiting.
  @Test func aReportFromSomethingOtherThanTheShellLeavesTheMarkWhereItIs() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    harness.stateSource.send(SessionStateReport(state: .attention, sessionID: session.id))
    #expect(model.agentIDAtThePrompt(of: session) == "codex")
  }

  /// An agent's own hooks report while it works and never name a command,
  /// so they must not take back the mark the shell put there.
  @Test func anAgentsOwnReportLeavesTheShellsAnswerWhereItIs() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "codex"))
    #expect(model.agentIDAtThePrompt(of: session) == "codex")
  }

  @Test func aTabOpenedForCodexOrOpenCodeDrawsThatAgentsMark() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)

    for id in ["codex", "opencode"] {
      model.newAgentTab(id)
      let tab = harness.store.workspace.tabs.last!
      #expect(model.agentIDAtThePrompt(of: tab) == id)
    }
  }
}
