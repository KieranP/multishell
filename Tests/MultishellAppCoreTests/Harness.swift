import Foundation
import TestScratch

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@MainActor
final class Harness {
  let model: AppModel<FakeSurface>
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let stateSource = FakeStateSource()
  let notifier = FakeNotifier()
  let platform = FakePlatform()
  /// Live, not the copy made at setup: `Project` is a value and its shared
  /// settings are read into the store afterwards.
  var project: Project { model.workspace.projects[0] }
  let main: Worktree
  let feature: Worktree
  let root: URL
  let stateFile: URL

  /// `socketSource` stands in for `stateSource`, for a test of the real socket.
  init(
    savedSelection: Bool = false,
    stateFile: URL? = nil,
    socketSource: (any SessionStateSource)? = nil,
  ) {
    root = Scratch.path("appmodel")
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    self.stateFile = stateFile ?? root.appendingPathComponent("state.json")
    store = WorkspaceStore(file: StateFile(fileURL: self.stateFile))
    let added = store.addProject(at: root)  // exists on disk, so `select` accepts it
    main = Worktree(path: root, projectID: added.id, head: "a", branch: "main", isPrimary: true)
    feature = Worktree(
      path: root.appendingPathComponent("feature"),
      projectID: added.id,
      head: "b",
      branch: "feature",
    )
    try? FileManager.default.createDirectory(at: feature.path, withIntermediateDirectories: true)
    store.replaceWorktrees([main, feature], forProject: added.id)
    if savedSelection { store.selectWorktree(main.id) }

    model = AppModel(
      store: store,
      host: engine,
      coordinator: nil,
      watcher: watcher,
      platform: platform,
      stateSource: socketSource ?? stateSource,
      notifier: notifier,
    )
    model.statusReadLog.pace = .unpaced
    model.refreshAppLaunchFiles = { _ in }
    model.sweepPromisedDropCopies = {}
    let path = root.appendingPathComponent("bin").path
    model.captureLoginEnvironment = { [root] in
      LoginShellEnvironment(
        variables: ["PATH": path, "HOME": root.path],
        source: .loginShell(URL(fileURLWithPath: "/bin/zsh")),
      )
    }
  }

  /// A test's own agent on a PATH nothing else has, so detection reads the
  /// scratch directory and not the machine.
  func installFakeAgent(_ name: String) throws {
    try fakeBin([name], in: root.appendingPathComponent("bin", isDirectory: true))
  }

  /// The model's tasks are `@MainActor`, so yielding hands them the actor this test holds; a
  /// handful of turns covers one that awaits a port on the way.
  func settled(turns: Int = 10) async {
    for _ in 0..<turns { await Task.yield() }
  }

  /// The alert a save that ran off the main actor raised, waiting up to a
  /// second for the write to come back; `nil` where none did.
  func presentedErrorArrives() async -> PresentedError? {
    try? await waitUntil({ model.presentedError != nil }, seconds: 1)
    return model.presentedError
  }

  /// Saves, then starts the model a fresh launch would: a store read back from
  /// the same file, a new engine, and no git.
  func relaunched() -> (
    model: AppModel<FakeSurface>, engine: FakeEngine, store: WorkspaceStore,
    loadError: (any Error)?
  ) {
    model.saveNow()
    let (store, loadError) = WorkspaceStore.restored(from: StateFile(fileURL: stateFile))
    let engine = FakeEngine()
    let model = AppModel(store: store, host: engine, coordinator: nil, watcher: FakeWatcher())
    return (model, engine, store, loadError)
  }

  deinit { Scratch.remove(root) }
}
