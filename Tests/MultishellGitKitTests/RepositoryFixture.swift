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

  static func make(commit: Bool = true) async throws -> RepositoryFixture {
    let runner = try TestGit.runner()
    let root = Scratch.path("gitkit")
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try await TestRepository.initialise(at: repository, using: runner)
    let fixture = RepositoryFixture(runner: runner, root: root, project: Project(path: repository))
    if commit { try await TestRepository.commitInitial(in: repository, using: runner) }
    return fixture
  }

  /// A bare clone with its worktrees beside it. `project` is the bare repository, which
  /// `git worktree list` puts first; `checkout` is a linked worktree of `main`.
  static func makeBare() async throws -> (fixture: RepositoryFixture, checkout: URL) {
    let source = try await make()
    let bare = source.root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await source.runner.run(
      ["clone", "-q", "--bare", source.project.path.path, bare.path], in: source.root)
    let checkout = source.root.appendingPathComponent("main", isDirectory: true)
    _ = try await source.runner.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)
    let fixture = RepositoryFixture(
      runner: source.runner, root: source.root, project: Project(path: bare))
    return (fixture, checkout)
  }

  func commit(_ message: String, file: String, content: String) async throws {
    try await commit(message, files: [file: content])
  }

  /// One commit writing several files, which is what a squash merge lands.
  func commit(_ message: String, files: [String: String]) async throws {
    try await TestRepository.commit(message, files: files, in: project.path, using: runner)
  }

  func head(of directory: URL) async throws -> String {
    try await runner.run(["rev-parse", "HEAD"], in: directory).trimmingCharacters(
      in: .whitespacesAndNewlines)
  }

  func branches() async throws -> [String] {
    try await runner.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: project.path
    )
    .split(whereSeparator: \.isNewline).map(String.init).sorted()
  }

  var coordinator: WorktreeCoordinator {
    WorktreeCoordinator(git: WorktreeGit(runner: runner, settlesNewIndex: false))
  }
  var worktreeSettings: WorktreeSettings { WorktreeSettings(worktreeDirectory: "../trees") }

  func worktree(onBranch branch: String, in project: Project? = nil) async throws -> Worktree {
    try #require(
      try await coordinator.git.list(project ?? self.project).first { $0.branch == branch })
  }

  func tearDown() {
    Scratch.remove(root)
  }
}
