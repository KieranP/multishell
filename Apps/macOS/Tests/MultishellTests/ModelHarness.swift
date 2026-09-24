import AppKit
import MultishellAppCore
import MultishellCore

@testable import Multishell

/// The Mac model with no git, watcher or engine behind it, for tests that only
/// read and write settings or lay a view out.
@MainActor
final class ModelHarness {
  let model: Multishell.AppModel
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
      snapshot: WorkspaceSnapshot(fileURL: directory.appendingPathComponent("state.json")))
    project = store.addProject(at: directory)
    self.store = store
    model = Multishell.AppModel(
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

@MainActor
final class NoEngine: TerminalSurfaceHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws {}
  func close(_ id: TerminalSession.ID) {}
  func focus(_ id: TerminalSession.ID) {}
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool { false }
  func view(for id: TerminalSession.ID) -> NSView? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}

@MainActor
final class NoWatcher: DirectoryWatcher {
  var onChange: (@MainActor ([URL]) -> Void)?
  func watch(_ directories: [URL]) {}
  func stop() {}
}
