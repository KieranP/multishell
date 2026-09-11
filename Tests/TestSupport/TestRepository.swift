import Foundation
import MultishellGitKit
import TestScratch

/// A throwaway git repository, as both the GitKit and the AppCore suites
/// want one.
///
/// The two built it separately and identically, down to the committer name,
/// so changing what a fixture repository looks like meant remembering two
/// files in two targets.
public enum TestRepository {
  /// What fixture commits are authored as. Not a real address.
  public static let committerEmail = "tests@multishell.local"
  public static let committerName = "Multishell Tests"
  /// Named rather than taken from the machine's `init.defaultBranch`, which
  /// a developer may have set to anything.
  public static let initialBranch = "main"

  /// An initialised repository at `url`, with the fixture identity set on the
  /// repository itself so a developer's global config cannot change what the
  /// tests commit as. No commit yet; `commit` makes the first.
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
}
