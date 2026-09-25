import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct WorkspaceRetiredAgentsTests {
  @Test func anAgentNoLongerInTheCatalogueIsForgottenWhereverItWasStored() {
    var project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    project.settings.preferredAgentID = "cursor-agent"
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    var retired = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "aider")
    retired.agentID = "aider"
    var kept = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "claude")
    kept.agentID = AgentCatalogue.claudeID
    var workspace = Workspace()
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.sessions = [retired, kept]
    workspace.preferredAgentID = "aider"

    workspace.forgetRetiredAgents()

    #expect(workspace.sessions.map(\.agentID) == [nil, AgentCatalogue.claudeID])
    #expect(workspace.preferredAgentID == nil)
    #expect(workspace.projects[0].settings.preferredAgentID == nil)
  }

  @Test func aRetiredAgentsTabIsTitledAsAPlainShell() {
    let path = URL(fileURLWithPath: "/repos/demo")
    let worktree = Worktree(
      path: path, projectID: path.path, head: "a", branch: "main", isPrimary: true)
    var retired = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "Aider")
    retired.agentID = "aider"
    var kept = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "Claude Code")
    kept.agentID = AgentCatalogue.claudeID
    var workspace = Workspace()
    workspace.sessions = [retired, kept]

    workspace.forgetRetiredAgents()

    #expect(workspace.sessions.map(\.title) == ["", "Claude Code"])
    #expect(workspace.sessions[0].displayTitle == t("tab.shell"))
  }

  @Test @MainActor func aStoreRestoredFromAFileNamingARetiredAgentForgetsIt() throws {
    let file = Scratch.path("retired").appendingPathComponent("state.json")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    var workspace = Workspace()
    workspace.preferredAgentID = "aider"
    let stateFile = WorkspaceFile(fileURL: file)
    try stateFile.save(workspace)

    let restored = WorkspaceStore.restored(from: stateFile)

    #expect(restored.loadError == nil)
    #expect(restored.store.workspace.preferredAgentID == nil)
  }
}
