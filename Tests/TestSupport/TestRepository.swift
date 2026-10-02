import Foundation

@testable import MultishellGitKit

/// A throwaway git repository, shared by the GitKit and AppCore suites so what a fixture
/// repository looks like is decided in one place.
public enum TestRepository {
  /// What fixture commits are authored as. Not a real address.
  static let committerEmail = "tests@multishell.local"
  public static let committerName = "Multishell Tests"
  /// Named rather than taken from the machine's `init.defaultBranch`, which
  /// a developer may have set to anything.
  static let initialBranch = "main"

  /// The fixture identity goes on the repository itself, so a developer's global config
  /// cannot change what the tests commit as. No commit yet; `commit` makes the first.
  public static func initialise(at url: URL, using git: GitRunner) async throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=\(initialBranch)"], in: url)
    _ = try await git.run(["config", "user.email", committerEmail], in: url)
    _ = try await git.run(["config", "user.name", committerName], in: url)
  }

  /// One commit writing `files`, which with several is what a squash merge
  /// lands.
  public static func commit(
    _ message: String, files: [String: String], in url: URL, using git: GitRunner
  ) async throws {
    for (file, content) in files {
      let path = url.appendingPathComponent(file)
      try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
      try content.write(to: path, atomically: true, encoding: .utf8)
    }
    _ = try await git.run(["add", "."], in: url)
    _ = try await git.run(["commit", "-q", "-m", message], in: url)
  }

  /// The first commit, which is what makes `HEAD` resolvable and so what most
  /// fixtures need before they can do anything.
  public static func commitInitial(in url: URL, using git: GitRunner) async throws {
    try await commit("initial", files: ["README.md": "hello\n"], in: url, using: git)
  }

  /// A bare clone of `repository` at `root/repo.git`, with `main` checked out
  /// in a linked worktree at `root/<worktree>`.
  public static func bareClone(
    of repository: URL, in root: URL, worktree: String, using git: GitRunner
  ) async throws -> (bare: URL, checkout: URL) {
    let bare = root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await git.run(["clone", "-q", "--bare", repository.path, bare.path], in: root)
    let checkout = root.appendingPathComponent(worktree, isDirectory: true)
    _ = try await git.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)
    return (bare, checkout)
  }

  /// Local branch names, sorted.
  public static func branches(in url: URL, using git: GitRunner) async throws -> [String] {
    try await git.run(["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: url)
      .split(whereSeparator: \.isNewline).map(String.init).sorted()
  }

  /// What a forge's squash merge leaves once `branch` is pushed: one commit of
  /// its whole tree on `main`, pushed, and the branch deleted on `origin`.
  public static func squashMergeOnTheRemote(
    _ branch: String, files: [String: String], in mainCheckout: URL, using git: GitRunner
  ) async throws {
    try await commit("squashed work", files: files, in: mainCheckout, using: git)
    _ = try await git.run(["push", "-q", "origin", "main"], in: mainCheckout)
    _ = try await git.run(["push", "-q", "origin", "--delete", branch], in: mainCheckout)
    _ = try await git.run(["fetch", "-q", "--prune", "origin"], in: mainCheckout)
  }

  /// A bare `origin` at `root/origin.git`, so a branch can be pushed and then
  /// deleted on the remote the way a merge does.
  public static func addOrigin(
    to repository: URL, in root: URL, using git: GitRunner
  )
    async throws
  {
    let origin = root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await git.run(["clone", "-q", "--bare", repository.path, origin.path], in: root)
    _ = try await git.run(["remote", "add", "origin", origin.path], in: repository)
    _ = try await git.run(["fetch", "-q", "origin"], in: repository)
  }
}
