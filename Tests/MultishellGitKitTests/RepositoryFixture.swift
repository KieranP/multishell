import Foundation
import MultishellCore

@testable import MultishellGitKit

/// A throwaway repository under the temp directory, removed on `tearDown`.
struct RepositoryFixture {
  let git: GitRunner
  let root: URL
  let project: Project

  static func make(commit: Bool = true) async throws -> RepositoryFixture {
    let git = try GitRunner()
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-tests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=main"], in: repository)
    _ = try await git.run(["config", "user.email", "tests@multishell.local"], in: repository)
    _ = try await git.run(["config", "user.name", "Multishell Tests"], in: repository)
    let fixture = RepositoryFixture(git: git, root: root, project: Project(path: repository))
    if commit { try await fixture.commit("initial", file: "README.md", content: "hello\n") }
    return fixture
  }

  /// The layout this app's audience favours: a bare clone with its worktrees
  /// beside it. `project` is the bare repository, as `git worktree list`
  /// puts it first; `checkout` is a linked worktree of `main`.
  static func makeBare() async throws -> (fixture: RepositoryFixture, checkout: URL) {
    let source = try await make()
    let bare = source.root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await source.git.run(
      ["clone", "-q", "--bare", source.project.path.path, bare.path], in: source.root)
    let checkout = source.root.appendingPathComponent("main", isDirectory: true)
    _ = try await source.git.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)
    return (
      RepositoryFixture(git: source.git, root: source.root, project: Project(path: bare)), checkout
    )
  }

  func commit(_ message: String, file: String, content: String) async throws {
    try content.write(
      to: project.path.appendingPathComponent(file), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: project.path)
    _ = try await git.run(["commit", "-q", "-m", message], in: project.path)
  }

  func head(of directory: URL) async throws -> String {
    try await git.run(["rev-parse", "HEAD"], in: directory).trimmingCharacters(
      in: .whitespacesAndNewlines)
  }

  func branches() async throws -> [String] {
    try await git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: project.path
    )
    .split(whereSeparator: \.isNewline).map(String.init).sorted()
  }

  var coordinator: WorktreeCoordinator { WorktreeCoordinator(service: WorktreeService(git: git)) }
  var trees: WorktreeSettings { WorktreeSettings(worktreeDirectory: "../trees") }

  func tearDown() {
    try? FileManager.default.removeItem(at: root)
  }
}

extension WorktreeCoordinator {
  /// The removal with the directory unlinked in place of a Trash, for tests
  /// about the git side of it.
  func remove(
    _ worktree: Worktree, deletingBranch: Bool = false, in project: Project,
    shellPath: String? = nil, onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil
  ) async throws {
    try await remove(
      worktree, deletingBranch: deletingBranch, in: project, shellPath: shellPath,
      trash: { try FileManager.default.removeItem(at: $0) }, onStep: onStep)
  }
}
