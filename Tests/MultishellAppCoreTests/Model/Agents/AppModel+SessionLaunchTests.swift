import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelSessionLaunchTests {
  @Test func eachTabRunsTheShellInForceForItsProject() {
    let harness = Harness()
    let session = TerminalSession(
      worktreeID: harness.main.id,
      workingDirectory: harness.main.path,
      title: "Shell",
    )
    #expect(harness.model.preparedForLaunch(session).shellPath == ShellChoice.loginShellPath())

    harness.model.setPreferredShell("/bin/bash")
    #expect(harness.model.preparedForLaunch(session).shellOverride == "/bin/bash")

    harness.model.setSettings(ProjectSettings(preferredShellID: "/bin/sh"), for: harness.project)
    #expect(
      harness.model.preparedForLaunch(session).shellOverride == "/bin/sh",
      "the project's override wins",
    )

    harness.model.setSettings(
      ProjectSettings(preferredShellID: ShellChoice.loginShellID),
      for: harness.project,
    )
    #expect(
      harness.model.preparedForLaunch(session).shellOverride == ShellChoice.loginShellPath(),
      "a project can step back to $SHELL under a global choice",
    )

    harness.model.select(harness.main)
    #expect(
      harness.engine.opened.last?.shellOverride == ShellChoice.loginShellPath(),
      "reaches the engine",
    )
    #expect(
      harness.model.workspace.sessions.allSatisfy { $0.shellOverride == nil },
      "never in the workspace",
    )
  }

  @Test func anAgentTabsFollowingShellIsTheChosenOne() {
    let harness = Harness()
    harness.model.setPreferredShell("/bin/sh")
    harness.model.setPreferredAgent(AgentCatalogue.customID)
    harness.model.setCustomAgentCommand("my-agent")
    let session = TerminalSession(
      worktreeID: harness.main.id,
      workingDirectory: harness.main.path,
      title: "Agent",
      agentID: AgentCatalogue.customID,
    )

    let prepared = harness.model.preparedForLaunch(session)

    #expect(prepared.command?.last == "my-agent; exec /bin/sh -l")
  }

  /// The flags are the user's, so they reach the command line whole, with
  /// `{{branch}}` standing for the tab's own worktree.
  @Test func anAgentTabCarriesTheFlagsWithItsPlaceholdersFilledIn() {
    let harness = Harness()
    harness.model.setPreferredShell("/bin/sh")
    harness.model.setPreferredAgent(AgentCatalogue.claudeID)
    harness.model.agentDetection = AgentDetection(found: [
      "claude": URL(fileURLWithPath: "/bin/claude")
    ])
    harness.model.setAgentFlags("--name={{branch}} --model opus", for: AgentCatalogue.claudeID)
    let session = TerminalSession(
      worktreeID: harness.feature.id,
      workingDirectory: harness.feature.path,
      title: "Claude Code",
      agentID: AgentCatalogue.claudeID,
    )

    #expect(
      harness.model.preparedForLaunch(session).command?.last
        == "claude '--name=feature' --model opus; exec /bin/sh -l"
    )

    harness.model.setSettings(ProjectSettings(agentFlags: "--model haiku"), for: harness.project)
    #expect(
      harness.model.preparedForLaunch(session).command?.last
        == "claude --model haiku; exec /bin/sh -l",
      "the project's line replaces the global one",
    )

    harness.model.setSettings(ProjectSettings(agentFlags: ""), for: harness.project)
    #expect(
      harness.model.preparedForLaunch(session).command?.last == "claude; exec /bin/sh -l",
      "blank runs it bare under a global that passes flags",
    )
  }

  /// A saved tab that comes back as `claude --continue` is the same tab,
  /// and the flags said how that tab is meant to run.
  @Test func aResumedAgentTabIsStartedWithTheFlagsToo() {
    let file = Scratch.statePath("agent-flags")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.setPreferredAgent(AgentCatalogue.claudeID)
    before.model.setAgentFlags("--name={{branch}}", for: AgentCatalogue.claudeID)
    before.model.select(before.main)
    before.store.openTab(
      in: before.main.id,
      title: "Claude Code",
      agentID: AgentCatalogue.claudeID,
    )

    let (after, engine, store, _) = before.relaunched()
    after.select(before.main)

    let opened = engine.opened.first { store.workspace.session($0.id)?.title == "Claude Code" }
    #expect(opened?.command?.last?.hasPrefix("claude --continue '--name=main'; ") == true)
  }

  @Test func aTaskFollowsTheFlagsOnTheFirstLaunchOnly() {
    let harness = Harness()
    harness.model.setPreferredShell("/bin/sh")
    harness.model.agentDetection = AgentDetection(found: [
      "claude": URL(fileURLWithPath: "/bin/claude")
    ])
    harness.model.setAgentFlags("--model opus", for: AgentCatalogue.claudeID)
    let session = TerminalSession(
      worktreeID: harness.feature.id,
      workingDirectory: harness.feature.path,
      title: "Claude Code",
      agentID: AgentCatalogue.claudeID,
    )
    harness.model.pendingAgentTasks[session.id] = "Fix the redirect"

    #expect(
      harness.model.preparedForLaunch(session).command?.last
        == "claude --model opus -- 'Fix the redirect'; exec /bin/sh -l"
    )
    #expect(
      harness.model.preparedForLaunch(session).command?.last
        == "claude --model opus; exec /bin/sh -l",
      "a relaunch in the same run does not ask again",
    )
  }

  @Test func aCustomCommandReadsItsTaskAndAnEmptyOneWithout() {
    let harness = Harness()
    harness.model.setPreferredShell("/bin/sh")
    harness.model.setCustomAgentCommand("my-agent {{task}}")
    let session = TerminalSession(
      worktreeID: harness.main.id,
      workingDirectory: harness.main.path,
      title: "Agent",
      agentID: AgentCatalogue.customID,
    )
    harness.model.pendingAgentTasks[session.id] = "Fix the redirect"

    let command = harness.model.preparedForLaunch(session).command
    #expect(command?.prefix(2) == ["/usr/bin/env", "MULTISHELL_TASK=Fix the redirect"])
    #expect(
      harness.model.preparedForLaunch(session).command?.prefix(2)
        == ["/usr/bin/env", "MULTISHELL_TASK="],
      "never left as the literal token for the shell to read",
    )
  }

  @Test func aRenamedWorktreeAndACustomCommandTakePlaceholdersToo() {
    let harness = Harness()
    harness.model.setPreferredShell("/bin/sh")
    harness.model.setPreferredAgent(AgentCatalogue.customID)
    harness.model.setCustomAgentCommand("my-agent --name={{worktree}}")
    harness.model.renameWorktree(harness.feature.id, to: "The fix")
    let session = TerminalSession(
      worktreeID: harness.feature.id,
      workingDirectory: harness.feature.path,
      title: "Agent",
      agentID: AgentCatalogue.customID,
    )

    let command = harness.model.preparedForLaunch(session).command
    #expect(command?.last == #"my-agent --name="$MULTISHELL_WORKTREE_NAME"; exec /bin/sh -l"#)
    #expect(
      command?.prefix(2) == ["/usr/bin/env", "MULTISHELL_WORKTREE_NAME=The fix"],
      "the value is handed over around the shell, never written into its line",
    )
  }

  @Test func theCustomShellPathReachesTabsUnlessTheProjectOverridesIt() {
    let harness = Harness()
    let session = TerminalSession(
      worktreeID: harness.main.id,
      workingDirectory: harness.main.path,
      title: "Shell",
    )
    harness.model.setPreferredShell(ShellChoice.customID)
    #expect(
      harness.model.preparedForLaunch(session).shellOverride == ShellChoice.loginShellPath(),
      "blank path",
    )

    harness.model.setCustomShellPath("/no/such/shell")
    #expect(harness.model.preparedForLaunch(session).shellOverride == "/no/such/shell")

    harness.model.setCustomShellPath(" /bin/sh ")
    #expect(harness.model.preparedForLaunch(session).shellOverride == "/bin/sh")
    harness.model.setSettings(ProjectSettings(preferredShellID: "/bin/bash"), for: harness.project)
    #expect(
      harness.model.preparedForLaunch(session).shellOverride == "/bin/bash",
      "a project override still wins",
    )
  }

  @Test func aSavedAgentTabResumesWhereItCanAndIsAShellWhereItCannot() {
    let file = Scratch.statePath("agent-relaunch")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.select(before.main)
    before.store.openTab(in: before.main.id, title: "Claude Code", agentID: "claude")
    before.store.openTab(in: before.main.id, title: "Flagless", agentID: "flagless")

    let (after, engine, store, _) = before.relaunched()
    after.select(before.main)

    let byTitle = Dictionary(
      uniqueKeysWithValues: engine.opened.map { (store.workspace.session($0.id)!.title, $0) }
    )
    #expect(byTitle["Claude Code"]?.command?.last?.hasPrefix("claude --continue; ") == true)
    #expect(
      byTitle["Flagless"]?.command == nil,
      "no resume flag, so a plain shell keeps the title",
    )
    #expect(after.title(of: store.workspace.tabs(in: before.main.id)[2]) == "Flagless")
  }

  @Test func anAgentThatIsNotInstalledOpensAShellAndSaysSoOnce() {
    let harness = Harness()
    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: ["PATH": "/usr/bin"],
      source: .loginShell(URL(fileURLWithPath: "/bin/zsh")),
    )
    harness.model.agentDetection = AgentDetection(searchPath: "/usr/bin")
    harness.model.setPreferredAgent("claude")
    harness.model.select(harness.main)
    harness.model.presentedError = nil

    harness.model.newAgentTab()
    #expect(harness.engine.opened.last?.command == nil)
    #expect(harness.model.presentedError?.title == "Claude Code is not installed")

    harness.model.presentedError = nil
    harness.model.newAgentTab()
    #expect(harness.model.presentedError == nil, "reported once per run")
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 3)
  }

  @Test func theCustomEntryRunsWhatWasTyped() {
    let harness = Harness()
    harness.model.setPreferredAgent("custom")
    harness.model.setCustomAgentCommand("my-agent --fast")
    harness.model.select(harness.main)
    harness.model.newAgentTab()
    #expect(harness.engine.opened.last?.command?.last?.hasPrefix("my-agent --fast; ") == true)
    #expect(
      harness.model.title(of: harness.model.workspace.activeTab(in: harness.main.id)!)
        == "Custom command"
    )
  }
}
