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
  let source = FakeStateSource()
  let notifier = FakeNotifier()
  let platform = FakePlatform()
  /// Live, not the copy made at setup: `Project` is a value and its shared
  /// settings are read into the store afterwards.
  var project: Project { model.workspace.projects[0] }
  let main: Worktree
  let feature: Worktree
  let root: URL

  init(savedSelection: Bool = false, stateFile: URL? = nil) {
    let tmp = Scratch.path("appmodel")
    root = tmp
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    store = WorkspaceStore(
      file: WorkspaceFile(
        fileURL: stateFile ?? tmp.appendingPathComponent("state.json")))
    let added = store.addProject(at: tmp)  // exists on disk, so `select` accepts it
    main = Worktree(path: tmp, projectID: added.id, head: "a", branch: "main", isPrimary: true)
    feature = Worktree(
      path: tmp.appendingPathComponent("feature"), projectID: added.id, head: "b",
      branch: "feature")
    try? FileManager.default.createDirectory(at: feature.path, withIntermediateDirectories: true)
    store.replaceWorktrees([main, feature], forProject: added.id)
    if savedSelection { store.selectWorktree(main.id) }

    model = AppModel(
      store: store, host: engine, coordinator: nil, watcher: watcher, platform: platform,
      stateSource: source, notifier: notifier)
    model.statusReads.pace = .unpaced
    model.refreshAppLaunchFiles = { _ in nil }
    model.sweepPromisedDropCopies = {}
    let path = tmp.appendingPathComponent("bin").path
    model.captureLoginEnvironment = {
      LoginShellEnvironment(
        variables: ["PATH": path, "HOME": tmp.path],
        source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    }
  }

  /// A test's own agent on a PATH nothing else has, so detection reads the
  /// scratch directory and not the machine.
  func installFakeAgent(_ name: String) throws {
    let bin = root.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try Scratch.script("exit 0", at: bin.appendingPathComponent(name))
  }

  deinit { Scratch.remove(root) }

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
}
