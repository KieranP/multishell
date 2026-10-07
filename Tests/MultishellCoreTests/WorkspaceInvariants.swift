import Foundation
import Testing

@testable import MultishellCore

/// What must hold between the workspace's collections after any store
/// operation, and what `repairReferences` restores after a load.
enum WorkspaceInvariants {
  static func check(_ workspace: Workspace, _ context: String) {
    let projectIDs = Set(workspace.projects.map(\.id))
    let worktreeIDs = Set(workspace.worktrees.map(\.id))
    let sessionIDs = Set(workspace.sessions.map(\.id))
    let groupIDs = Set(workspace.tabGroups.map(\.id))
    #expect(projectIDs.count == workspace.projects.count, "\(context): a project listed twice")
    #expect(worktreeIDs.count == workspace.worktrees.count, "\(context): a worktree listed twice")
    #expect(sessionIDs.count == workspace.sessions.count, "\(context): a session listed twice")
    #expect(groupIDs.count == workspace.tabGroups.count, "\(context): a tab group listed twice")

    #expect(
      workspace.worktrees.allSatisfy { projectIDs.contains($0.projectID) },
      "\(context): orphan worktree")
    #expect(
      workspace.tabs.allSatisfy { worktreeIDs.contains($0.worktreeID) }, "\(context): orphan tab")
    checkGroups(workspace, context, worktreeIDs: worktreeIDs)

    var owned: [TerminalSession.ID: Int] = [:]
    for tab in workspace.tabs {
      #expect(!tab.sessionIDs.isEmpty, "\(context): empty tab")
      #expect(tab.root.contains(tab.focusedSessionID), "\(context): focus outside its tree")
      for id in tab.sessionIDs {
        #expect(sessionIDs.contains(id), "\(context): pane without a session")
        // Warmth, and so whether a session's shell runs at all, is decided from the
        // session's own copy of its worktree.
        if let session = workspace.session(id) {
          #expect(
            session.worktreeID == tab.worktreeID, "\(context): a pane in another worktree")
        }
        owned[id, default: 0] += 1
      }
      #expect(weightsAligned(tab.root), "\(context): weights out of step with children")
    }
    #expect(owned.values.allSatisfy { $0 == 1 }, "\(context): a session in two panes")
    #expect(sessionIDs.allSatisfy { owned[$0] != nil }, "\(context): session no tab owns")

    for (worktreeID, name) in workspace.customWorktreeNames {
      #expect(worktreeIDs.contains(worktreeID), "\(context): a name for a missing worktree")
      #expect(
        !name.trimmingCharacters(in: .whitespaces).isEmpty, "\(context): a blank custom name")
    }
    if let selected = workspace.selectedWorktreeID {
      #expect(worktreeIDs.contains(selected), "\(context): selection of a missing worktree")
    }
  }

  private static func checkGroups(
    _ workspace: Workspace, _ context: String, worktreeIDs: Set<Worktree.ID>
  ) {
    for group in workspace.tabGroups {
      #expect(worktreeIDs.contains(group.worktreeID), "\(context): orphan tab group")
      let tabsHere = workspace.tabs(inGroup: group.id)
      #expect(!tabsHere.isEmpty, "\(context): a tab group with no tabs")
      #expect(
        group.shownTabID != nil && tabsHere.contains { $0.id == group.shownTabID },
        "\(context): a tab group showing a tab that is not its own")
      #expect(group.weight.isFinite && group.weight > 0, "\(context): a tab group with no width")
    }
    for tab in workspace.tabs {
      #expect(
        workspace.group(tab.groupID)?.worktreeID == tab.worktreeID,
        "\(context): a tab in another worktree's group, or in none")
    }
    for (worktreeID, groupID) in workspace.focusedGroupByWorktree {
      #expect(
        workspace.group(groupID)?.worktreeID == worktreeID,
        "\(context): the focused group is not the worktree's")
    }
    for worktreeID in Set(workspace.tabGroups.map(\.worktreeID)) {
      #expect(
        workspace.focusedGroupByWorktree[worktreeID] != nil, "\(context): groups but none focused")
    }
  }

  private static func weightsAligned(_ node: PaneNode) -> Bool {
    switch node {
    case .terminal: return true
    case .split(_, let children, let weights):
      return children.count == weights.count && children.count >= 2
        && children.allSatisfy(weightsAligned)
    }
  }
}
