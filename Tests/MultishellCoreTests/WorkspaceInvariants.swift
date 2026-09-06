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
    #expect(projectIDs.count == ws.projects.count, "\(context): a project listed twice")
    #expect(worktreeIDs.count == ws.worktrees.count, "\(context): a worktree listed twice")
    #expect(sessionIDs.count == ws.sessions.count, "\(context): a session listed twice")

    #expect(
      ws.worktrees.allSatisfy { projectIDs.contains($0.projectID) }, "\(context): orphan worktree")
    #expect(ws.tabs.allSatisfy { worktreeIDs.contains($0.worktreeID) }, "\(context): orphan tab")

    var owned: [TerminalSession.ID: Int] = [:]
    for tab in ws.tabs {
      #expect(!tab.sessionIDs.isEmpty, "\(context): empty tab")
      #expect(tab.root.contains(tab.focusedSessionID), "\(context): focus outside its tree")
      for id in tab.sessionIDs {
        #expect(sessionIDs.contains(id), "\(context): pane without a session")
        owned[id, default: 0] += 1
      }
      #expect(weightsAligned(tab.root), "\(context): weights out of step with children")
    }
    #expect(owned.values.allSatisfy { $0 == 1 }, "\(context): a session in two panes")
    #expect(sessionIDs.allSatisfy { owned[$0] != nil }, "\(context): session no tab owns")

    for (worktreeID, tabID) in ws.activeTabByWorktree {
      #expect(
        ws.tab(tabID)?.worktreeID == worktreeID, "\(context): active tab is not the worktree's")
    }
    for worktreeID in worktreeIDs where !ws.tabs(in: worktreeID).isEmpty {
      #expect(ws.activeTabByWorktree[worktreeID] != nil, "\(context): tabs but no active one")
    }
    for (worktreeID, name) in ws.worktreeNames {
      #expect(worktreeIDs.contains(worktreeID), "\(context): a name for a missing worktree")
      #expect(
        !name.trimmingCharacters(in: .whitespaces).isEmpty, "\(context): a blank custom name")
    }
    if let selected = ws.selectedWorktreeID {
      #expect(worktreeIDs.contains(selected), "\(context): selection of a missing worktree")
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
