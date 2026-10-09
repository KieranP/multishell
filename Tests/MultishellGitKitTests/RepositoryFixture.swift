import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

/// A throwaway repository under the temp directory, removed on `tearDown`.
struct RepositoryFixture {
  let runner: GitRunner
  let root: URL
  let project: Project

  var coordinator: WorktreeCoordinator { TestGit.coordinator(runner: runner) }
  var worktreeSettings: WorktreeSettings { WorktreeSettings(worktreeDirectory: "../trees") }

  static func make(commit: Bool = true) async throws -> Self {
    let runner = try TestGit.runner()
    let root = Scratch.path("gitkit")
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try await TestRepository.initialise(at: repository, withFirstCommit: commit, using: runner)
    return Self(runner: runner, root: root, project: Project(path: repository))
  }

  /// A bare clone with its worktrees beside it. `project` is the bare repository, which
  /// `git worktree list` puts first; `checkout` is a linked worktree of `main`.
  static func makeBare() async throws -> (fixture: Self, checkout: URL) {
    let source = try await make()
    let (bare, checkout) = try await TestRepository.bareClone(
      of: source.project.path,
      in: source.root,
      worktree: "main",
      using: source.runner,
    )
    let fixture = Self(
      runner: source.runner,
      root: source.root,
      project: Project(path: bare),
    )
    return (fixture, checkout)
  }

  func commit(_ message: String, file: String, content: String) async throws {
    try await commit(message, files: [file: content])
  }

  /// One commit writing several files, which is what a squash merge lands.
  func commit(_ message: String, files: [String: String]) async throws {
    try await TestRepository.commit(message, files: files, in: project.path, using: runner)
  }

  /// A branch off `main` with one commit on it, the checkout back on `main` after.
  func commitOnBranch(
    _ branch: String,
    file: String,
    content: String,
    message: String = "work",
  ) async throws {
    _ = try await runner.run(["checkout", "-q", "-b", branch], in: project.path)
    try await commit(message, file: file, content: content)
    _ = try await runner.run(["checkout", "-q", "main"], in: project.path)
  }

  /// A linked worktree under `trees/` on a new branch cut where `main` is.
  func addWorktree(onNewBranch branch: String) async throws -> URL {
    let tree = root.appendingPathComponent("trees/\(branch)", isDirectory: true)
    try await TestRepository.addWorktree(
      onNewBranch: branch,
      at: tree,
      in: project.path,
      using: runner,
    )
    return tree
  }

  /// A worktree whose directory has gone, leaving git's record of it stale.
  func worktreeWithItsDirectoryGone(
    lockedFor reason: String? = nil
  ) async throws -> (record: Worktree, path: URL) {
    let branch = "old"
    let path = try await coordinator.createThenRunPostCreateHook(
      branch: branch,
      in: project,
      settings: worktreeSettings,
    )
    if let reason {
      _ = try await runner.run(
        ["worktree", "lock", "--reason", reason, path.path],
        in: project.path,
      )
    }
    let record = try await worktree(onBranch: branch)
    try FileManager.default.removeItem(at: path)
    return (record, path)
  }

  func head(of directory: URL) async throws -> String {
    try await runner.run(["rev-parse", "HEAD"], in: directory).trimmingCharacters(
      in: .whitespacesAndNewlines
    )
  }

  func branches() async throws -> [String] {
    try await TestRepository.branches(in: project.path, using: runner)
  }

  func worktree(onBranch branch: String, in project: Project? = nil) async throws -> Worktree {
    try #require(
      try await coordinator.git.list(project ?? self.project).first { $0.branch == branch }
    )
  }

  func tearDown() {
    Scratch.remove(root)
  }
}
