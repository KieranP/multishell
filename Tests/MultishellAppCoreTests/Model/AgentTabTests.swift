import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

/// Agent tabs: the store keeps an id, the shell gets a command line.
@Suite @MainActor
struct AgentTabTests {
  @Test func newAgentTabRecordsTheIdAndOpensTheAgentThroughTheLoginShell() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)

    h.model.newAgentTab()

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = h.model.workspace.session(tab.focusedSessionID)!
    #expect(session.agentID == "claude")
    #expect(session.command == nil, "the store never holds the command line")
    #expect(h.model.title(of: tab) == "Claude Code")
    let opened = h.engine.opened.last!
    #expect(opened.id == session.id)
    #expect(opened.command?.last?.hasPrefix("claude; ") == true, "\(opened.command ?? [])")
    #expect(opened.command?.last?.contains("exec ") == true, "a shell takes over after the agent")
  }

  @Test func theProjectOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    #expect(h.model.preferredAgentID(for: h.main) == "claude")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "codex"), for: h.project)
    #expect(h.model.preferredAgentID(for: h.main) == "codex")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "none"), for: h.project)
    #expect(h.model.preferredAgentID(for: h.main) == nil)
    h.model.select(h.main)
    let tabs = h.model.workspace.tabs(in: h.main.id).count
    h.model.presentedError = nil
    h.model.newAgentTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == tabs)
    #expect(h.model.presentedError?.title == "No agent chosen")
  }

  @Test func aSavedAgentTabResumesWhereItCanAndIsAShellWhereItCannot() throws {
    let file = Scratch.path("agent-relaunch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.select(before.main)
    before.store.openTab(in: before.main.id, title: "Claude Code", agentID: "claude")
    before.store.openTab(in: before.main.id, title: "Flagless", agentID: "flagless")
    before.model.saveNow()

    let (store, _) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: engine, worktrees: nil,
      watcher: FakeWatcher())
    after.select(before.main)

    let byTitle = Dictionary(
      uniqueKeysWithValues: engine.opened.map { (store.workspace.session($0.id)!.title, $0) })
    #expect(byTitle["Claude Code"]?.command?.last?.hasPrefix("claude --continue; ") == true)
    #expect(byTitle["Flagless"]?.command == nil, "no resume flag, so a plain shell keeps the title")
    #expect(after.title(of: store.workspace.tabs(in: before.main.id)[2]) == "Flagless")
  }

  @Test func anAgentThatIsNotInstalledOpensAShellAndSaysSoOnce() {
    let h = Harness()
    h.model.loginEnvironment = LoginShellEnvironment(
      variables: ["PATH": "/usr/bin"], source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    h.model.agentDetection = AgentDetection(path: "/usr/bin")
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)
    h.model.presentedError = nil

    h.model.newAgentTab()
    #expect(h.engine.opened.last?.command == nil)
    #expect(h.model.presentedError?.title == "Claude Code is not installed")

    h.model.presentedError = nil
    h.model.newAgentTab()
    #expect(h.model.presentedError == nil, "reported once per run")
    #expect(h.model.workspace.tabs(in: h.main.id).count == 3)
  }

  @Test func autoStartMakesNewTabAndTheFirstTabTheAgentButNeverASplit() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)

    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    #expect(
      h.model.workspace.session(first.focusedSessionID)?.agentID == "claude",
      "the first tab after select, which is what follows a create")
    #expect(h.model.title(of: first) == "Claude Code")

    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!
    #expect(h.model.workspace.session(second.focusedSessionID)?.agentID == "claude")

    h.model.splitActivePane(.horizontal)
    let split = h.model.workspace.tab(second.id)!
    let pane = split.sessionIDs.first { $0 != second.focusedSessionID }!
    #expect(h.model.workspace.session(pane)?.agentID == nil, "splits stay plain shells")

    h.model.newShellTab()
    let shell = h.model.workspace.activeTab(in: h.main.id)!
    #expect(
      h.model.workspace.session(shell.focusedSessionID)?.agentID == nil, "a shell stays reachable")
  }

  @Test func autoStartOffOrNoAgentOpensShellsAndTheProjectOverrideWins() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == nil, "off by default")

    h.model.updateSettings(ProjectSettings(autoStartAgent: true), for: h.project)
    h.model.newTab()
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == "claude", "the project override turns it on")

    h.model.setAutoStartAgent(true)
    h.model.updateSettings(ProjectSettings(autoStartAgent: false), for: h.project)
    h.model.newTab()
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == nil, "the project override turns it off")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "none"), for: h.project)
    h.model.newTab()
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == nil, "auto-start with no agent in force is a shell")
  }

  @Test func theCustomEntryRunsWhatWasTyped() {
    let h = Harness()
    h.model.setPreferredAgent("custom")
    h.model.setCustomAgentCommand("my-agent --fast")
    h.model.select(h.main)
    h.model.newAgentTab()
    #expect(h.engine.opened.last?.command?.last?.hasPrefix("my-agent --fast; ") == true)
    #expect(h.model.title(of: h.model.workspace.activeTab(in: h.main.id)!) == "Custom command")
  }

  /// A saved agent tab clicked while PATH is still being scanned must not read as missing,
  /// so the environment and what was found on it land together.
  @Test func theEnvironmentIsNotKnownBeforeItsPathHasBeenScanned() async {
    let h = Harness()
    let refresh = Task { await h.model.refreshLoginEnvironment() }
    while h.model.loginEnvironment == nil { try? await Task.sleep(for: .milliseconds(1)) }
    #expect(h.model.shellDetection != .empty, "/etc/shells alone fills this")
    #expect(h.model.agentDetection == AgentDetection(path: h.model.loginEnvironment?.path))
    await refresh.value
  }

  @Test func theNewTabMenuListsWhatWasFoundAndTheCustomCommandOnlyWhenTyped() throws {
    let bin = try fakeBin(["codex", "claude"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let h = Harness()
    h.model.agentDetection = AgentDetection(path: bin.path)

    #expect(h.model.installedAgentIDs == ["claude", "codex"], "catalogue order")

    h.model.setCustomAgentCommand("  ")
    #expect(h.model.installedAgentIDs == ["claude", "codex"], "a blank line is no agent")

    h.model.setCustomAgentCommand("my-agent --fast")
    #expect(h.model.installedAgentIDs == ["claude", "codex", "custom"])

    // Its own store: a second model over the harness's would deselect the
    // worktree under it, `init` clearing the selection.
    let saved = WorkspaceStore(
      snapshot: WorkspaceSnapshot(
        fileURL: Scratch.path("relaunch").appendingPathComponent("state.json")))
    saved.setCustomAgentCommand("my-agent --fast")
    let relaunched = AppModel(
      store: saved, host: FakeEngine(), worktrees: nil, watcher: FakeWatcher())
    #expect(relaunched.installedAgentIDs == ["custom"], "the saved command, before any PATH scan")
  }

  @Test func aNamedAgentTabNeedsNoPreferredAgentAndOpensInTheColumnGiven() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let columns = h.model.workspace.groups(in: h.main.id)
    #expect(h.model.preferredAgentID(for: h.main) == nil)
    h.model.presentedError = nil

    h.model.newAgentTab("opencode", in: columns[0].id)

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.groupID == columns[0].id)
    #expect(h.model.workspace.session(tab.focusedSessionID)?.agentID == "opencode")
    #expect(h.model.title(of: tab) == "OpenCode")
    #expect(h.model.presentedError == nil, "the strip named the agent, so none was chosen for it")
  }

  @Test func theNewTabMenusShellTabOpensInTheColumnGiven() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let columns = h.model.workspace.groups(in: h.main.id)

    h.model.newShellTab(in: columns[0].id)

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.groupID == columns[0].id)
    #expect(h.model.workspace.session(tab.focusedSessionID)?.agentID == nil)
  }

  @Test func theLoginEnvironmentFeedsDetection() async throws {
    let h = Harness()
    try h.installFakeAgent("claude")
    #expect(h.model.loginEnvironment == nil)
    await h.model.refreshLoginEnvironment()
    #expect(h.model.loginEnvironment?.path != nil)
    #expect(h.model.agentDetection.found[AgentCatalogue.claudeID] != nil, "found on that PATH")
    #expect(h.model.agentDetection == AgentDetection(path: h.model.loginEnvironment?.path))
  }
}
