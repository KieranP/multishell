import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import TestSupport

@testable import MultishellGitKit

/// A throwaway repository under the temp directory, removed on `tearDown`.
struct RepositoryFixture {
  let git: GitRunner
  let root: URL
  let project: Project

  static func make(commit: Bool = true) async throws -> RepositoryFixture {
    let git = try TestGit.build()
    let root = Scratch.path("gitkit")
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try await TestRepository.initialise(at: repository, using: git)
    let fixture = RepositoryFixture(git: git, root: root, project: Project(path: repository))
    if commit { try await TestRepository.commitInitial(in: repository, using: git) }
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
    try await commit(message, files: [file: content])
  }

  /// One commit writing several files, which is what a squash merge lands.
  func commit(_ message: String, files: [String: String]) async throws {
    try await TestRepository.commit(message, files: files, in: project.path, using: git)
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
    Scratch.remove(root)
  }
}

extension WorktreeCoordinator {
  /// Both halves of a create in one call, in the order `AppModel` runs them:
  /// `add`, then the post-create hook, with the same `.postCreateHook` step
  /// reported before a hook that has a script.
  ///
  /// The app keeps them apart so a worktree appears, and can be worked in,
  /// while a slow hook is still running. A test about the git side has no
  /// use for that, so it waits here for both.
  @discardableResult
  func create(
    branch rawBranch: String,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    settings: WorktreeSettings,
    shellPath: String? = nil,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeCreationStep) -> Void)? = nil
  ) async throws -> URL {
    let path = try await add(
      branch: rawBranch, basedOn: startPoint, createBranch: createBranch, in: project,
      settings: settings, shellPath: shellPath, timeout: timeout, stopper: stopper, onStep: onStep)
    if WorktreeHooks.hasScript(project.settings.postCreateHook) { onStep?(.postCreateHook) }
    try await runPostCreate(
      for: project, worktreePath: path,
      branch: Self.branchName(rawBranch, createBranch: createBranch, settings: settings),
      shellPath: shellPath, timeout: timeout, stopper: stopper)
    return path
  }

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
