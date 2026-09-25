import Foundation
import MultishellCore
import MultishellProcess

/// The git side of worktree management. Knows nothing about hooks or settings.
/// Its reads are public, the app asking them through the coordinator's `git`.
public struct WorktreeGit: Sendable {
  let runner: GitRunner
  /// Shared by the copies of this value, and by those a later git makes.
  let shared: SharedGitReads

  /// Off only in the suites, whose hundreds of creates would each wait a second.
  let settlesNewIndex: Bool

  init(
    runner: GitRunner, settlesNewIndex: Bool = true, shared: SharedGitReads = SharedGitReads()
  ) {
    self.runner = runner
    self.settlesNewIndex = settlesNewIndex
    self.shared = shared
  }

  init(searchPath: String? = nil) throws {
    self.init(runner: try GitRunner(searchPath: searchPath))
  }

  /// `--git-dir`, not `--is-inside-work-tree`, which prints `false` for a
  /// bare repository: a common layout for people who live in worktrees.
  public func isRepository(_ url: URL) async -> Bool {
    await runner.succeeds(["rev-parse", "--git-dir"], in: url)
  }

  /// False for a freshly initialised repository. `HEAD` is unborn there, so
  /// nothing can be branched from it until the first commit.
  public func hasCommits(_ project: Project) async -> Bool {
    await runner.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: project.path)
  }

  /// The `.git` directory every worktree shares, where git records them. Stable
  /// for a project's life, so the watcher and the records check need no spawn.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    let output = try await runner.run(
      ["rev-parse", Self.absolutePathFormat, "--git-common-dir"], in: project.path)
    guard let common = Self.absolutePaths(in: output, from: project.path).first else {
      throw ProcessFailure.git(
        ["rev-parse", "--git-common-dir"],
        message: "git named no common directory for \(project.path.path)")
    }
    return common
  }
}
