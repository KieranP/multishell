import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTabOpeningTests {
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

  @Test func aNamedAgentTabNeedsNoPreferredAgentAndOpensInTheGroupGiven() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let groups = h.model.workspace.groups(in: h.main.id)
    #expect(h.model.preferredAgentID(for: h.main) == nil)
    h.model.presentedError = nil

    h.model.newAgentTab("opencode", in: groups[0].id)

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.groupID == groups[0].id)
    #expect(h.model.workspace.session(tab.focusedSessionID)?.agentID == "opencode")
    #expect(h.model.title(of: tab) == "OpenCode")
    #expect(h.model.presentedError == nil, "the strip named the agent, so none was chosen for it")
  }

  @Test func theNewTabMenusShellTabOpensInTheGroupGiven() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let groups = h.model.workspace.groups(in: h.main.id)

    h.model.newShellTab(in: groups[0].id)

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.groupID == groups[0].id)
    #expect(h.model.workspace.session(tab.focusedSessionID)?.agentID == nil)
  }
}
