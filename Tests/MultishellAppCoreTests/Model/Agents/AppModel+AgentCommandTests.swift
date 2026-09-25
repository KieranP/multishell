import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelAgentCommandTests {
  @Test func eachTabRunsTheShellInForceForItsProject() {
    let h = Harness()
    let session = TerminalSession(
      worktreeID: h.main.id, workingDirectory: h.main.path, title: "Shell")
    #expect(h.model.preparedForLaunch(session).shellPath == ShellCatalogue.loginShellPath())

    h.model.setPreferredShell("/bin/bash")
    #expect(h.model.preparedForLaunch(session).shellOverride == "/bin/bash")

    h.model.updateSettings(ProjectSettings(preferredShellID: "/bin/sh"), for: h.project)
    #expect(
      h.model.preparedForLaunch(session).shellOverride == "/bin/sh", "the project's override wins")

    h.model.updateSettings(
      ProjectSettings(preferredShellID: ShellCatalogue.loginShellID), for: h.project)
    #expect(
      h.model.preparedForLaunch(session).shellOverride == ShellCatalogue.loginShellPath(),
      "a project can step back to $SHELL under a global choice")

    h.model.select(h.main)
    #expect(
      h.engine.opened.last?.shellOverride == ShellCatalogue.loginShellPath(), "reaches the engine")
    #expect(
      h.model.workspace.sessions.allSatisfy { $0.shellOverride == nil }, "never in the workspace")
  }

  @Test func anAgentTabsFollowingShellIsTheChosenOne() {
    let h = Harness()
    h.model.setPreferredShell("/bin/sh")
    h.model.setPreferredAgent(AgentCatalogue.customID)
    h.model.setCustomAgentCommand("my-agent")
    let session = TerminalSession(
      worktreeID: h.main.id, workingDirectory: h.main.path, title: "Agent",
      agentID: AgentCatalogue.customID)

    let prepared = h.model.preparedForLaunch(session)

    #expect(prepared.command?.last == "my-agent; exec /bin/sh -l")
  }
  /// The flags are the user's, so they reach the command line whole, with
  /// `{{branch}}` standing for the tab's own worktree.
  @Test func anAgentTabCarriesTheFlagsWithItsPlaceholdersFilledIn() {
    let h = Harness()
    h.model.setPreferredShell("/bin/sh")
    h.model.setPreferredAgent(AgentCatalogue.claudeID)
    h.model.agentDetection = AgentDetection(found: ["claude": URL(fileURLWithPath: "/bin/claude")])
    h.model.setAgentFlags("--name={{branch}} --model opus", for: AgentCatalogue.claudeID)
    let session = TerminalSession(
      worktreeID: h.feature.id, workingDirectory: h.feature.path, title: "Claude Code",
      agentID: AgentCatalogue.claudeID)

    #expect(
      h.model.preparedForLaunch(session).command?.last
        == "claude '--name=feature' --model opus; exec /bin/sh -l"
    )

    h.model.updateSettings(ProjectSettings(agentFlags: "--model haiku"), for: h.project)
    #expect(
      h.model.preparedForLaunch(session).command?.last == "claude --model haiku; exec /bin/sh -l",
      "the project's line replaces the global one")

    h.model.updateSettings(ProjectSettings(agentFlags: ""), for: h.project)
    #expect(
      h.model.preparedForLaunch(session).command?.last == "claude; exec /bin/sh -l",
      "blank runs it bare under a global that passes flags")
  }
  /// A saved tab that comes back as `claude --continue` is the same tab,
  /// and the flags said how that tab is meant to run.
  @Test func aResumedAgentTabIsStartedWithTheFlagsToo() throws {
    let file = Scratch.path("agent-flags")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.setPreferredAgent(AgentCatalogue.claudeID)
    before.model.setAgentFlags("--name={{branch}}", for: AgentCatalogue.claudeID)
    before.model.select(before.main)
    before.store.openTab(in: before.main.id, title: "Claude Code", agentID: AgentCatalogue.claudeID)
    before.model.saveNow()

    let (store, _) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: engine, coordinator: nil,
      watcher: FakeWatcher())
    after.select(before.main)

    let opened = engine.opened.first { store.workspace.session($0.id)?.title == "Claude Code" }
    #expect(opened?.command?.last?.hasPrefix("claude --continue '--name=main'; ") == true)
  }

  @Test func aRenamedWorktreeAndACustomCommandTakePlaceholdersToo() {
    let h = Harness()
    h.model.setPreferredShell("/bin/sh")
    h.model.setPreferredAgent(AgentCatalogue.customID)
    h.model.setCustomAgentCommand("my-agent --name={{worktree}}")
    h.model.renameWorktree(h.feature.id, to: "The fix")
    let session = TerminalSession(
      worktreeID: h.feature.id, workingDirectory: h.feature.path, title: "Agent",
      agentID: AgentCatalogue.customID)

    let command = h.model.preparedForLaunch(session).command
    #expect(command?.last == #"my-agent --name="$MULTISHELL_WORKTREE_NAME"; exec /bin/sh -l"#)
    #expect(
      command?.prefix(2) == ["/usr/bin/env", "MULTISHELL_WORKTREE_NAME=The fix"],
      "the value is handed over around the shell, never written into its line")
  }

  @Test func theCustomShellPathReachesTabsAndTheCaptionSaysWhenItWillNot() {
    let h = Harness()
    let session = TerminalSession(
      worktreeID: h.main.id, workingDirectory: h.main.path, title: "Shell")
    h.model.setPreferredShell(ShellCatalogue.customID)
    #expect(
      h.model.preparedForLaunch(session).shellOverride == ShellCatalogue.loginShellPath(),
      "blank path")
    #expect(h.model.customShellPathProblem?.hasPrefix("Blank") == true)
    #expect(h.model.shellDisplayName(ShellCatalogue.customID).contains("blank"))

    h.model.setCustomShellPath("/no/such/shell")
    #expect(h.model.preparedForLaunch(session).shellOverride == "/no/such/shell")
    #expect(h.model.customShellPathProblem?.hasPrefix("Nothing executable") == true)

    h.model.setCustomShellPath(" /bin/sh ")
    #expect(h.model.preparedForLaunch(session).shellOverride == "/bin/sh")
    #expect(h.model.customShellPathProblem == nil)
    #expect(h.model.shellDisplayName(ShellCatalogue.customID) == "the custom path /bin/sh")
    h.model.updateSettings(ProjectSettings(preferredShellID: "/bin/bash"), for: h.project)
    #expect(
      h.model.preparedForLaunch(session).shellOverride == "/bin/bash",
      "a project override still wins")
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

    let (store, _) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: engine, coordinator: nil,
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
    h.model.agentDetection = AgentDetection(searchPath: "/usr/bin")
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

  @Test func theCustomEntryRunsWhatWasTyped() {
    let h = Harness()
    h.model.setPreferredAgent("custom")
    h.model.setCustomAgentCommand("my-agent --fast")
    h.model.select(h.main)
    h.model.newAgentTab()
    #expect(h.engine.opened.last?.command?.last?.hasPrefix("my-agent --fast; ") == true)
    #expect(h.model.title(of: h.model.workspace.activeTab(in: h.main.id)!) == "Custom command")
  }
}
