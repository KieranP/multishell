import Foundation
import Testing

@testable import MultishellCore

/// What must hold between the workspace's collections after any store
/// operation, and what `repairReferences` restores after a load.
enum WorkspaceInvariants {
  static func check(_ ws: Workspace, _ context: String) {
    let projectIDs = Set(ws.projects.map(\.id))
    let worktreeIDs = Set(ws.worktrees.map(\.id))
    let sessionIDs = Set(ws.sessions.map(\.id))
    let groupIDs = Set(ws.tabGroups.map(\.id))
    #expect(projectIDs.count == ws.projects.count, "\(context): a project listed twice")
    #expect(worktreeIDs.count == ws.worktrees.count, "\(context): a worktree listed twice")
    #expect(sessionIDs.count == ws.sessions.count, "\(context): a session listed twice")
    #expect(groupIDs.count == ws.tabGroups.count, "\(context): a tab group listed twice")

    #expect(
      ws.worktrees.allSatisfy { projectIDs.contains($0.projectID) }, "\(context): orphan worktree")
    #expect(ws.tabs.allSatisfy { worktreeIDs.contains($0.worktreeID) }, "\(context): orphan tab")
    checkGroups(ws, context, worktreeIDs: worktreeIDs)

    var owned: [TerminalSession.ID: Int] = [:]
    for tab in ws.tabs {
      #expect(!tab.sessionIDs.isEmpty, "\(context): empty tab")
      #expect(tab.root.contains(tab.focusedSessionID), "\(context): focus outside its tree")
      for id in tab.sessionIDs {
        #expect(sessionIDs.contains(id), "\(context): pane without a session")
        // A session's worktree is the worktree of the tab that shows it:
        // warmth, and so whether its shell is running at all, is decided
        // from the session's own copy.
        if let session = ws.session(id) {
          #expect(
            session.worktreeID == tab.worktreeID, "\(context): a pane in another worktree")
        }
        owned[id, default: 0] += 1
      }
      #expect(weightsAligned(tab.root), "\(context): weights out of step with children")
    }
    #expect(owned.values.allSatisfy { $0 == 1 }, "\(context): a session in two panes")
    #expect(sessionIDs.allSatisfy { owned[$0] != nil }, "\(context): session no tab owns")

    for (worktreeID, name) in ws.worktreeNames {
      #expect(worktreeIDs.contains(worktreeID), "\(context): a name for a missing worktree")
      #expect(
        !name.trimmingCharacters(in: .whitespaces).isEmpty, "\(context): a blank custom name")
    }
    if let selected = ws.selectedWorktreeID {
      #expect(worktreeIDs.contains(selected), "\(context): selection of a missing worktree")
    }
  }

  /// A worktree's columns: every one belongs to a worktree that exists,
  /// holds at least one tab, shows one of its own tabs, and has a width
  /// something can be laid out in. Every tab sits in a column of its own
  /// worktree, and a worktree with columns has one of them focused.
  private static func checkGroups(
    _ ws: Workspace, _ context: String, worktreeIDs: Set<Worktree.ID>
  ) {
    for group in ws.tabGroups {
      #expect(worktreeIDs.contains(group.worktreeID), "\(context): orphan tab group")
      let tabsHere = ws.tabs(in: group.id)
      #expect(!tabsHere.isEmpty, "\(context): a tab group with no tabs")
      #expect(
        group.activeTabID != nil && tabsHere.contains { $0.id == group.activeTabID },
        "\(context): a tab group showing a tab that is not its own")
      #expect(group.weight.isFinite && group.weight > 0, "\(context): a tab group with no width")
    }
    for tab in ws.tabs {
      #expect(
        ws.group(tab.groupID)?.worktreeID == tab.worktreeID,
        "\(context): a tab in another worktree's column, or in none")
    }
    for (worktreeID, groupID) in ws.focusedGroupByWorktree {
      #expect(
        ws.group(groupID)?.worktreeID == worktreeID,
        "\(context): the focused column is not the worktree's")
    }
    for worktreeID in Set(ws.tabGroups.map(\.worktreeID)) {
      #expect(
        ws.focusedGroupByWorktree[worktreeID] != nil, "\(context): columns but none focused")
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

/// Deterministic, so a failing sequence can be replayed from its seed.
struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}
