import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTabOpeningTests {
  @Test func newAgentTabRecordsTheIdAndOpensTheAgentThroughTheLoginShell() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.select(harness.main)

    harness.model.newAgentTab()

    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let session = harness.model.workspace.session(tab.focusedSessionID)!
    #expect(session.agentID == "claude")
    #expect(session.command == nil, "the store never holds the command line")
    #expect(harness.model.title(of: tab) == "Claude Code")
    let opened = harness.engine.opened.last!
    #expect(opened.id == session.id)
    #expect(opened.command?.last?.hasPrefix("claude; ") == true, "\(opened.command ?? [])")
    #expect(opened.command?.last?.contains("exec ") == true, "a shell takes over after the agent")
  }

  @Test func autoStartMakesNewTabAndTheFirstTabTheAgentButNeverASplit() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgent(true)

    harness.model.select(harness.main)
    let first = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(
      harness.model.workspace.session(first.focusedSessionID)?.agentID == "claude",
      "the first tab after select, which is what follows a create",
    )
    #expect(harness.model.title(of: first) == "Claude Code")

    harness.model.newTab()
    let second = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(harness.model.workspace.session(second.focusedSessionID)?.agentID == "claude")

    harness.model.splitActivePane(.horizontal)
    let split = harness.model.workspace.tab(second.id)!
    let pane = split.sessionIDs.first { $0 != second.focusedSessionID }!
    #expect(harness.model.workspace.session(pane)?.agentID == nil, "splits stay plain shells")

    harness.model.newShellTab()
    let shell = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(
      harness.model.workspace.session(shell.focusedSessionID)?.agentID == nil,
      "a shell stays reachable",
    )
  }

  @Test func autoStartOffOrNoAgentOpensShellsAndTheProjectOverrideWins() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.select(harness.main)
    #expect(
      harness.model.workspace.session(
        harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID
      )?
      .agentID == nil,
      "off by default",
    )

    harness.model.setSettings(ProjectSettings(autoStartsAgent: true), for: harness.project)
    harness.model.newTab()
    #expect(
      harness.model.workspace.session(
        harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID
      )?
      .agentID == "claude",
      "the project override turns it on",
    )

    harness.model.setAutoStartsAgent(true)
    harness.model.setSettings(ProjectSettings(autoStartsAgent: false), for: harness.project)
    harness.model.newTab()
    #expect(
      harness.model.workspace.session(
        harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID
      )?
      .agentID == nil,
      "the project override turns it off",
    )

    harness.model.setSettings(ProjectSettings(preferredAgentID: "none"), for: harness.project)
    harness.model.newTab()
    #expect(
      harness.model.workspace.session(
        harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID
      )?
      .agentID == nil,
      "auto-start with no agent in force is a shell",
    )
  }

  @Test func aNamedAgentTabNeedsNoPreferredAgentAndOpensInTheGroupGiven() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    harness.model.moveActiveTabToNewGroup()
    let groups = harness.model.workspace.groups(in: harness.main.id)
    #expect(harness.model.effectiveAgentID(for: harness.main) == nil)
    harness.model.presentedError = nil

    harness.model.newAgentTab("opencode", in: groups[0].id)

    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(tab.groupID == groups[0].id)
    #expect(harness.model.workspace.session(tab.focusedSessionID)?.agentID == "opencode")
    #expect(harness.model.title(of: tab) == "OpenCode")
    #expect(
      harness.model.presentedError == nil,
      "the strip named the agent, so none was chosen for it",
    )
  }

  @Test func theNewTabMenusShellTabOpensInTheGroupGiven() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgent(true)
    harness.model.newTab()
    harness.model.moveActiveTabToNewGroup()
    let groups = harness.model.workspace.groups(in: harness.main.id)

    harness.model.newShellTab(in: groups[0].id)

    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(tab.groupID == groups[0].id)
    #expect(harness.model.workspace.session(tab.focusedSessionID)?.agentID == nil)
  }

  @Test func aMenusNewShellTabSelectsItsWorktreeAndOpensOnlyThatShell() throws {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgent(true)
    harness.model.select(harness.main)

    harness.model.newShellTab(selecting: harness.feature)

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    let tabs = harness.model.workspace.tabs(in: harness.feature.id)
    #expect(tabs.count == 1, "no first tab opened on the way")
    let session = try #require(harness.model.workspace.session(tabs[0].focusedSessionID))
    #expect(session.agentID == nil)
  }

  @Test func aMenusNewAgentTabSelectsItsWorktreeAndStartsThePreferredAgent() throws {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.select(harness.main)

    harness.model.newAgentTab(selecting: harness.feature)

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    let tabs = harness.model.workspace.tabs(in: harness.feature.id)
    #expect(tabs.count == 1)
    let session = try #require(harness.model.workspace.session(tabs[0].focusedSessionID))
    #expect(session.agentID == "claude")
  }

  @Test func aWorktreeThatCannotBeSelectedGetsNoTab() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try FileManager.default.removeItem(at: harness.feature.path)

    harness.model.newShellTab(selecting: harness.feature)
    harness.model.newAgentTab(selecting: harness.feature)

    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.tabs(in: harness.feature.id).isEmpty)
    #expect(
      harness.model.workspace.tabs(in: harness.main.id).count == 1,
      "nothing landed where it was",
    )
  }
}
