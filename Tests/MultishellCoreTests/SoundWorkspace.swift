import Foundation

@testable import MultishellCore

/// `/repos/demo` with its main worktree selected and one shell tab in one group, every
/// invariant held, so repair leaves it alone and a round trip returns it exactly.
func soundWorkspace() -> (workspace: Workspace, tab: TerminalTab) {
  var workspace = Workspace()
  let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
  let worktree = Worktree(
    path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
  let session = TerminalSession(
    worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
  var group = TabGroup(worktreeID: worktree.id)
  let tab = TerminalTab(worktreeID: worktree.id, groupID: group.id, session: session.id)
  group.activeTabID = tab.id
  workspace.projects = [project]
  workspace.worktrees = [worktree]
  workspace.sessions = [session]
  workspace.tabs = [tab]
  workspace.tabGroups = [group]
  workspace.focusedGroupByWorktree = [worktree.id: group.id]
  workspace.selectedWorktreeID = worktree.id
  return (workspace, tab)
}
