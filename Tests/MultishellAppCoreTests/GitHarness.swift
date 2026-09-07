import Foundation
import MultishellCore
import MultishellGitKit
import Observation
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
    git = try GitRunner()
    root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-appgit-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=main"], in: repository)
    _ = try await git.run(["config", "user.email", "tests@multishell.local"], in: repository)
    _ = try await git.run(["config", "user.name", "Multishell Tests"], in: repository)
    try "hello\n".write(
      to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: repository)
    _ = try await git.run(["commit", "-q", "-m", "initial"], in: repository)

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
    try """
    #!/bin/sh
    SCRATCH="\(root.path)"
    echo "$*" >> "$SCRATCH/calls"
    \(body)
    """.write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
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
    try? FileManager.default.removeItem(at: root)
  }
}

/// A box for `withObservationTracking`, whose callback may not capture a
/// mutable local.
final class Fired: @unchecked Sendable {
  var value = false
}
