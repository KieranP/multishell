import AppKit
import MultishellAppCore
import MultishellCore

@testable import MultishellAppUI

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
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-harness-\(UUID().uuidString)", isDirectory: true)
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = WorkspaceStore(
      file: WorkspaceFile(fileURL: directory.appendingPathComponent("state.json")))
    project = store.addProject(at: directory)
    self.store = store
    model = MultishellAppUI.AppModel(
      store: store,
      host: NoEngine(),
      worktrees: nil,
      watcher: NoWatcher())
  }

  deinit { try? FileManager.default.removeItem(at: directory) }

  /// The project's own settings, the repository's not layered in, which is
  /// what the settings forms edit.
  func settings(of project: Project) -> ProjectSettings {
    model.settings(of: project)
  }
}
