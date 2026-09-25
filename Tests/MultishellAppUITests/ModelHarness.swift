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
  /// Captured once, so it goes stale after a write; that is what
  /// `aBindingFollowsTheRecordAndNotTheProjectItWasBuiltWith` needs.
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

  deinit { ScratchDirectory.remove(directory) }
}
