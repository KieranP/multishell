import Foundation
import Testing

@testable import MultishellCore

/// Random sequences of the operations views can trigger, in any order. Every
/// step must leave the workspace consistent; a failure prints the seed and
/// the step so it can be replayed.
@Suite @MainActor
struct WorkspaceStoreInvariantTests {
  @Test(arguments: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89] as [UInt64])
  func anyOperationSequenceKeepsTheWorkspaceConsistent(seed: UInt64) throws {
    var rng = SeededGenerator(seed: seed)
    let store = WorkspaceStore()
    let projects = ["/repos/a", "/repos/b"].map { store.addProject(at: URL(fileURLWithPath: $0)) }
    var worktrees: [Worktree] = []
    for project in projects {
      for name in ["main", "feat", "spike"] {
        worktrees.append(
          Worktree(
            path: project.path.appendingPathComponent(name), projectID: project.id, head: name,
            branch: name))
      }
      store.replaceWorktrees(
        worktrees.filter { $0.projectID == project.id }, forProject: project.id)
    }

    for step in 0..<400 {
      let ws = store.workspace
      switch Int.random(in: 0..<17, using: &rng) {
      case 0, 1:
        if let worktree = worktrees.randomElement(using: &rng) {
          store.openTab(in: worktree.id)
        }
      case 2:
        if let tab = ws.tabs.randomElement(using: &rng) { store.closeTab(tab.id) }
      case 3, 4:
        if let tab = ws.tabs.randomElement(using: &rng) {
          store.splitFocusedPane(
            of: tab.id, axis: Bool.random(using: &rng) ? .horizontal : .vertical)
        }
      case 5:
        if let session = ws.sessions.randomElement(using: &rng) { store.closeSession(session.id) }
      case 6:
        if let session = ws.sessions.randomElement(using: &rng) { store.focusSession(session.id) }
      case 7:
        if let a = ws.tabs.randomElement(using: &rng), let b = ws.tabs.randomElement(using: &rng) {
          store.moveTab(a.id, Bool.random(using: &rng) ? .before : .after, b.id)
        }
      case 8:
        if let tab = ws.tabs.randomElement(using: &rng) {
          store.setSplitWeights(
            [Double.random(in: 0.1...3, using: &rng), Double.random(in: 0.1...3, using: &rng)],
            at: [], ofTab: tab.id)
        }
      case 9:
        // Naming a worktree, blanking a name, and naming one a refresh may
        // already have dropped.
        if let worktree = worktrees.randomElement(using: &rng) {
          store.setCustomName(
            ["Checkout flow", "  ", "", "Spike"].randomElement(using: &rng),
            forWorktree: worktree.id)
        }
      case 10:
        // A tab dragged onto another worktree's row.
        if let tab = ws.tabs.randomElement(using: &rng),
          let worktree = worktrees.randomElement(using: &rng)
        {
          store.moveTab(tab.id, to: worktree.id)
        }
      case 11:
        // The project settings forms: an override turned on, blanked, given
        // whitespace to opt out of a global, and turned off again. A blank
        // one has to come back as an override, which the round-trip check
        // below is what proves.
        let project = projects.randomElement(using: &rng)!
        var settings = ws.project(project.id)?.settings ?? ProjectSettings()
        let value = ["team/", "", "  ", "../trees"].randomElement(using: &rng)!
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: settings.branchPrefix = Bool.random(using: &rng) ? value : nil
        case 1: settings.worktreeDirectory = Bool.random(using: &rng) ? value : nil
        default: settings.defaultBranch = Bool.random(using: &rng) ? value : nil
        }
        store.updateSettings(settings, forProject: project.id)
      case 12:
        // A tab dragged to the band down one edge of a column.
        if let tab = ws.tabs.randomElement(using: &rng),
          let group = ws.tabGroups.randomElement(using: &rng)
        {
          store.moveTabToNewGroup(tab.id, Bool.random(using: &rng) ? .before : .after, of: group.id)
        }
      case 13:
        // A tab dropped on a column's strip clear of its tabs.
        if let tab = ws.tabs.randomElement(using: &rng),
          let group = ws.tabGroups.randomElement(using: &rng)
        {
          store.moveTab(tab.id, toEndOf: group.id)
        }
      case 14:
        if let group = ws.tabGroups.randomElement(using: &rng) { store.focusGroup(group.id) }
      case 15:
        // The divider between two columns, dragged; a count that does not
        // line up with the columns is refused.
        if let worktree = worktrees.randomElement(using: &rng) {
          store.setGroupWeights(
            (0..<Int.random(in: 1...3, using: &rng)).map { _ in
              Double.random(in: 0.1...3, using: &rng)
            }, in: worktree.id)
        }
      default:
        // A refresh that lost a worktree, or found one again.
        let project = projects.randomElement(using: &rng)!
        let kept = worktrees.filter { $0.projectID == project.id && Bool.random(using: &rng) }
        store.replaceWorktrees(kept, forProject: project.id)
        store.selectWorktree(worktrees.randomElement(using: &rng)?.id)
      }
      WorkspaceInvariants.check(store.workspace, "seed \(seed) step \(step)")
    }

    // Whatever shape the operations reached, a relaunch must reproduce it:
    // the encoder and the lossy decoder agree on every element, and repair
    // finds nothing to do in a workspace the store built.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(store.workspace)
    var restored = try JSONDecoder().decode(Workspace.self, from: data)
    #expect(restored == store.workspace, "seed \(seed): the file does not say what the store did")
    restored.repairReferences()
    #expect(restored == store.workspace, "seed \(seed): repair changed a sound workspace")
  }
}
