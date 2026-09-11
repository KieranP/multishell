import AppKit
import MultishellAppCore
import MultishellCore

@testable import Multishell

/// The Mac model with nothing behind it: no git, no watcher, no engine.
/// For tests that read and write settings or lay a view out, none of the
/// three is ever reached.
@MainActor
struct ModelHarness {
  let model: Multishell.AppModel
  let project: Project

  init() {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-harness-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: directory.appendingPathComponent("state.json")))
    project = store.addProject(at: directory)
    let engine = NoEngine()
    model = AppModel(
      store: store,
      host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: nil,
      watcher: NoWatcher())
  }

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
  var onChange: (@MainActor () -> Void)?
  func watch(_ directories: [URL]) {}
  func stop() {}
}
