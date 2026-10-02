import AppKit
import MultishellAppCore

@testable import MultishellAppUI
@testable import MultishellCore

/// The Mac model with no git, watcher or engine behind it, for tests that only
/// read and write settings or lay a view out.
@MainActor
final class ModelHarness {
  let model: MultishellAppUI.AppModel
  let store: WorkspaceStore
  /// Captured once, so it goes stale after a write; `live` is the store's copy.
  let project: Project
  /// The record as the store has it, which is what a reader passes.
  var live: Project { model.workspace.project(project.id) ?? project }
  private let directory: URL

  init() {
    let directory = ScratchDirectory.path("harness")
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = WorkspaceStore(
      file: WorkspaceFile(fileURL: directory.appendingPathComponent("state.json")))
    project = store.addProject(at: directory)
    self.store = store
    model = MultishellAppUI.AppModel(
      store: store,
      host: NoEngine(),
      coordinator: nil,
      watcher: NoWatcher())
  }

  /// The project's own checkout as its one worktree.
  @discardableResult
  func addPrimaryWorktree(branch: String = "main", head: String = "abc1234") -> Worktree {
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: head, branch: branch, isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    return worktree
  }

  deinit { ScratchDirectory.remove(directory) }
}
