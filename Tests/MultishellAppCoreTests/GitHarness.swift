import Foundation
import MultishellCore
import MultishellGitKit
import Observation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore

/// The model on real git, a fake engine and a fake watcher: what the sidebar
/// flows do from a click to the shells and the repository, in a throwaway
/// repository under the temp directory.
@MainActor
struct GitHarness {
  let root: URL
  let git: GitRunner
  let model: AppModel<FakeSurface>
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let platform = FakePlatform()

  init() async throws {
    git = try TestGit.build()
    root = Scratch.path("appgit")
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try await TestRepository.initialise(at: repository, using: git)
    try await TestRepository.commitInitial(in: repository, using: git)

    store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: root.appendingPathComponent("state.json")))
    let engine = self.engine
    model = AppModel(
      store: store,
      host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: WorktreeCoordinator(service: WorktreeService(git: git)),
      watcher: watcher, platform: platform)
    await model.addProject(at: repository)
  }

  /// Waits for the removal that `requestRemoval` or a dialog started, up to
  /// a few seconds, by watching the operation entry.
  func awaitOperationEnd(on id: Worktree.ID) async {
    for _ in 0..<200 where model.worktreeOperations[id]?.isRunning == true {
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  var project: Project { model.workspace.projects[0] }

  /// A second model on the same store, with a shell script standing in for
  /// git. `$SCRATCH` is the harness root; every call is appended to
  /// `$SCRATCH/calls`.
  func modelOnFakeGit(_ body: String) throws -> AppModel<FakeSurface> {
    let script = root.appendingPathComponent("fake-git-\(UUID().uuidString)")
    try Scratch.script(
      """
      SCRATCH="\(root.path)"
      echo "$*" >> "$SCRATCH/calls"
      \(body)
      """, at: script)
    let engine = self.engine
    let model = AppModel(
      store: store,
      host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: WorktreeCoordinator(
        service: WorktreeService(git: try GitRunner(executable: script))),
      watcher: watcher)
    model.presentedError = nil
    return model
  }

  func gitCalls() -> [String] {
    (try? String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8))?
      .split(whereSeparator: \.isNewline).map(String.init) ?? []
  }

  func worktree(onBranch branch: String) -> Worktree? {
    model.workspace.worktrees(of: project.id).first { $0.branch == branch }
  }

  func tearDown() {
    Scratch.remove(root)
  }
}

/// A box for `withObservationTracking`, whose callback may not capture a
/// mutable local.
final class Fired: @unchecked Sendable {
  var value = false
}
