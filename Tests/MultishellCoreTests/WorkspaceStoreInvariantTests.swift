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
      switch Int.random(in: 0..<11, using: &rng) {
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
          store.moveTab(a.id, before: b.id)
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
