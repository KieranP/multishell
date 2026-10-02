import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// Agent tabs: the store keeps an id.
@Suite @MainActor
struct AppModelAgentsTests {
  @Test func theProjectOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    #expect(h.model.effectiveAgentID(for: h.main) == "claude")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "codex"), for: h.project)
    #expect(h.model.effectiveAgentID(for: h.main) == "codex")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "none"), for: h.project)
    #expect(h.model.effectiveAgentID(for: h.main) == nil)
    h.model.select(h.main)
    let tabs = h.model.workspace.tabs(in: h.main.id).count
    h.model.presentedError = nil
    h.model.newAgentTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == tabs)
    #expect(h.model.presentedError?.title == "No agent chosen")
  }

  @Test func theNewTabMenuListsWhatWasFoundAndTheCustomCommandOnlyWhenTyped() throws {
    let bin = try fakeBin(["codex", "claude"])
    defer { Scratch.remove(bin) }
    let h = Harness()
    h.model.agentDetection = AgentDetection(searchPath: bin.path)

    #expect(h.model.newTabAgentIDs == ["claude", "codex"], "catalogue order")

    h.model.setCustomAgentCommand("  ")
    #expect(h.model.newTabAgentIDs == ["claude", "codex"], "a blank line is no agent")

    h.model.setCustomAgentCommand("my-agent --fast")
    #expect(h.model.newTabAgentIDs == ["claude", "codex", "custom"])

    // Its own store: a second model over the harness's would deselect the
    // worktree under it, `init` clearing the selection.
    let saved = WorkspaceStore(
      file: WorkspaceFile(
        fileURL: Scratch.path("relaunch").appendingPathComponent("state.json")))
    saved.setCustomAgentCommand("my-agent --fast")
    let relaunched = AppModel(
      store: saved, host: FakeEngine(), coordinator: nil, watcher: FakeWatcher())
    #expect(relaunched.newTabAgentIDs == ["custom"], "the saved command, before any PATH scan")
  }

  @Test func theFlagsFooterSaysWhenTheGlobalLineIsEmpty() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    #expect(
      h.model.globalAgentFlagsCaption(for: h.project) == "Using the global flags, which are none.")

    h.model.setAgentFlags("--verbose", for: "claude")

    #expect(
      h.model.globalAgentFlagsCaption(for: h.project) == "Using the global flags, --verbose.")
  }

  @Test func theCustomCommandFieldShowsOnlyForTheCustomAgent() {
    let h = Harness()
    h.model.setPreferredAgent(AgentCatalogue.customID)
    #expect(h.model.usesCustomAgent)

    h.model.setPreferredAgent("claude")
    #expect(!h.model.usesCustomAgent)
  }

  @Test func autoStartHasSomethingToStartOnlyOnceAnAgentIsChosen() {
    let h = Harness()
    h.model.setPreferredAgent(AgentCatalogue.noneID)
    #expect(!h.model.hasPreferredAgent)

    h.model.setPreferredAgent("claude")
    #expect(h.model.hasPreferredAgent)
  }

  @Test func theGlobalAgentIsNoneUntilOneIsChosen() {
    let h = Harness()
    #expect(h.model.globalAgentID == AgentCatalogue.noneID)
    #expect(!h.model.hasPreferredAgent)

    h.model.setPreferredAgent("claude")

    #expect(h.model.globalAgentID == "claude")
    #expect(h.model.hasPreferredAgent)
  }

  @Test func aStoredNoneIsNoPreferredAgent() {
    let h = Harness()
    h.store.setPreferredAgent(AgentCatalogue.noneID)

    #expect(h.model.globalAgentID == AgentCatalogue.noneID)
    #expect(!h.model.hasPreferredAgent)
  }

  /// The strip and the sidebar draw a mark from this, so a shell someone
  /// typed `claude` into has to stop looking like a shell.
  @Test func theMarkFollowsWhoIsAtThePromptRatherThanWhatOpenedTheTab() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    let tab = harness.store.workspace.tabs[0]

    #expect(model.agentAtThePrompt(of: tab) == nil, "a plain shell")
    #expect(model.agentAtThePrompt(of: session) == nil)

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "codex"))
    #expect(model.agentAtThePrompt(of: tab) == "codex")
    #expect(model.agentAtThePrompt(of: session) == "codex")
  }

  /// Typed at a prompt, with none of that agent's hooks installed: the
  /// shell's own report of what it just started is all the app has.
  @Test func aCommandThatIsAnAgentMarksThePaneUntilItFinishes() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    #expect(model.agentAtThePrompt(of: session) == "codex")
    #expect(model.agentBoardCards[0].occupant == .agent(id: "codex", name: "Codex"))

    harness.stateSource.send(
      SessionStateReport(state: .done, sessionID: session.id, isFromShellIntegration: true))
    #expect(model.agentAtThePrompt(of: session) == nil, "it exited, so the pane is a shell again")
  }

  /// A shell reports every command it starts and names only the agents, so
  /// the next unnamed one is the last agent's end whether a finish landed.
  @Test func aPlainCommandAfterAnAgentTakesTheMarkBack() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    #expect(model.agentAtThePrompt(of: session) == "codex")

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, isFromShellIntegration: true))
    #expect(model.agentAtThePrompt(of: session) == nil, "`ls` is not codex")
  }

  /// `multishell state` is documented for the user's own scripts, and one
  /// run from inside an agent's turn is not that agent's shell exiting.
  @Test func aReportFromSomethingOtherThanTheShellLeavesTheMarkWhereItIs() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    harness.stateSource.send(SessionStateReport(state: .attention, sessionID: session.id))
    #expect(model.agentAtThePrompt(of: session) == "codex")
  }

  /// An agent's own hooks report while it works and never name a command,
  /// so they must not take back the mark the shell put there.
  @Test func anAgentsOwnReportLeavesTheShellsAnswerWhereItIs() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session.id, command: "codex", isFromShellIntegration: true))
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "codex"))
    #expect(model.agentAtThePrompt(of: session) == "codex")
  }

  @Test func aTabOpenedForCodexOrOpenCodeDrawsThatAgentsMark() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)

    for id in ["codex", "opencode"] {
      model.newAgentTab(id)
      let tab = harness.store.workspace.tabs.last!
      #expect(model.agentAtThePrompt(of: tab) == id)
    }
  }
}
