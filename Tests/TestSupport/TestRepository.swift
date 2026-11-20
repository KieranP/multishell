import Foundation
import TestScratch

@testable import MultishellGitKit

/// A throwaway git repository, shared by the GitKit and AppCore suites so what a fixture
/// repository looks like is decided in one place.
public enum TestRepository {
  /// What fixture commits are authored as. Not a real address.
  private static let committerEmail = "tests@multishell.local"
  public static let committerName = "Multishell Tests"
  /// Named rather than taken from the machine's `init.defaultBranch`, which
  /// a developer may have set to anything.
  private static let initialBranch = "main"

  /// Hundreds of tests make a repository at once; copying one in place of five git runs
  /// each took the AppCore suites from 156 s to 89 s.
  private static let committedTemplate = Task {
    try await makeTemplate(named: "committed", withFirstCommit: true)
  }
  private static let emptyTemplate = Task {
    try await makeTemplate(named: "empty", withFirstCommit: false)
  }

  private static let templateRoot: URL = {
    atexit { Scratch.remove(Self.templateRoot) }
    return Scratch.path("repository-templates")
  }()

  /// A copy of a repository made once per process, whose own identity keeps a developer's
  /// global config out of what tests commit as; the first commit makes `HEAD` resolvable.
  public static func initialise(at url: URL, withFirstCommit: Bool) async throws {
    let template = try await (withFirstCommit ? committedTemplate : emptyTemplate).value
    let manager = FileManager.default
    try manager.createDirectory(at: url, withIntermediateDirectories: true)
    for item in try manager.contentsOfDirectory(atPath: template.path) {
      try manager.copyItem(
        at: template.appendingPathComponent(item),
        to: url.appendingPathComponent(item),
      )
    }
  }

  private static func makeTemplate(named name: String, withFirstCommit: Bool) async throws -> URL {
    let git = try TestGit.runner()
    let url = templateRoot.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=\(initialBranch)"], in: url)
    _ = try await git.run(["config", "user.email", committerEmail], in: url)
    _ = try await git.run(["config", "user.name", committerName], in: url)
    if withFirstCommit {
      try await commit("initial", files: ["README.md": "hello\n"], in: url, using: git)
    }
    return url
  }

  /// One commit writing `files`, which with several is what a squash merge
  /// lands.
  public static func commit(
    _ message: String,
    files: [String: String],
    in url: URL,
    using git: GitRunner,
  ) async throws {
    for (file, content) in files {
      let path = url.appendingPathComponent(file)
      try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      try content.write(to: path, atomically: true, encoding: .utf8)
    }
    _ = try await git.run(["add", "."], in: url)
    _ = try await git.run(["commit", "-q", "-m", message], in: url)
  }

  /// `data` written to `file` and committed alone, the file's name its message.
  public static func commit(
    _ data: Data,
    as file: String,
    in url: URL,
    using git: GitRunner,
  ) async throws {
    try data.write(to: url.appendingPathComponent(file))
    _ = try await git.run(["add", file], in: url)
    _ = try await git.run(["commit", "-q", "-m", file], in: url)
  }

  /// A bare clone of `repository` at `root/repo.git`, with `main` checked out
  /// in a linked worktree at `root/<worktree>`.
  public static func bareClone(
    of repository: URL,
    in root: URL,
    worktree: String,
    using git: GitRunner,
  ) async throws -> (bare: URL, checkout: URL) {
    let bare = root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await git.run(["clone", "-q", "--bare", repository.path, bare.path], in: root)
    let checkout = root.appendingPathComponent(worktree, isDirectory: true)
    _ = try await git.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)
    return (bare, checkout)
  }

  /// A linked worktree at `directory` on a new branch cut at `startPoint`, as
  /// `git worktree add -b` run by hand.
  public static func addWorktree(
    onNewBranch branch: String,
    at directory: URL,
    in repository: URL,
    using git: GitRunner,
    from startPoint: String = "HEAD",
  ) async throws {
    _ = try await git.run(
      ["worktree", "add", "-q", "-b", branch, directory.path, startPoint],
      in: repository,
    )
  }

  /// Local branch names, sorted.
  public static func branches(in url: URL, using git: GitRunner) async throws -> [String] {
    try await git.run(["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: url)
      .split(whereSeparator: \.isNewline).map(String.init).sorted()
  }

  /// What a forge's squash merge leaves once `branch` is pushed: one commit of
  /// its whole tree on `main`, pushed, and the branch deleted on `origin`.
  public static func squashMergeOnTheRemote(
    _ branch: String,
    files: [String: String],
    in mainCheckout: URL,
    using git: GitRunner,
  ) async throws {
    try await commit("squashed work", files: files, in: mainCheckout, using: git)
    _ = try await git.run(["push", "-q", "origin", "main"], in: mainCheckout)
    _ = try await git.run(["push", "-q", "origin", "--delete", branch], in: mainCheckout)
    _ = try await git.run(["fetch", "-q", "--prune", "origin"], in: mainCheckout)
  }

  /// A bare `origin` at `root/origin.git`, so a branch can be pushed and then
  /// deleted on the remote the way a merge does.
  public static func addOrigin(
    to repository: URL,
    in root: URL,
    using git: GitRunner,
  )
    async throws
  {
    let origin = root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await git.run(["clone", "-q", "--bare", repository.path, origin.path], in: root)
    _ = try await git.run(["remote", "add", "origin", origin.path], in: repository)
    _ = try await git.run(["fetch", "-q", "origin"], in: repository)
  }
}
