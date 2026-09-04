import Foundation
import MultishellCore
import MultishellProcess

/// The git side of worktree management. Knows nothing about hooks or settings.
public struct WorktreeService: Sendable {
  private let git: GitRunner

  public init(git: GitRunner) {
    self.git = git
  }

  public init() throws {
    self.git = try GitRunner()
  }

  public func isRepository(_ url: URL) async -> Bool {
    let output = try? await git.run(["rev-parse", "--is-inside-work-tree"], in: url)
    return output?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
  }

  /// False for a freshly initialised repository. `HEAD` is unborn there, so
  /// nothing can be branched from it until the first commit.
  public func hasCommits(_ project: Project) async -> Bool {
    await git.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: project.path)
  }

  public func list(_ project: Project) async throws -> [Worktree] {
    let output = try await git.run(["worktree", "list", "--porcelain"], in: project.path)
    return WorktreeListParser.parse(output, projectID: project.id)
  }

  /// The main worktree of the repository `url` is in, whether `url` is that
  /// worktree, a subdirectory of it, or a linked worktree. `git worktree
  /// list` puts the main worktree first from wherever it runs.
  public func mainWorktree(containing url: URL) async throws -> URL {
    let output = try await git.run(["worktree", "list", "--porcelain"], in: url)
    guard let main = WorktreeListParser.parse(output, projectID: "").first else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "no worktree listed for \(url.path)")
    }
    return main.path
  }

  public func status(of worktree: Worktree) async throws -> WorktreeStatus {
    let output = try await git.run(["status", "--porcelain=v1", "--branch"], in: worktree.path)
    return WorktreeStatusParser.parse(output)
  }

  public func localBranches(_ project: Project) async throws -> [String] {
    let output = try await git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"],
      in: project.path
    )
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// `origin/main`, `origin/feature`, ... with the symbolic `origin/HEAD`
  /// dropped. Full ref names are asked for because `%(refname:short)`
  /// abbreviates `refs/remotes/origin/HEAD` to just `origin`, which a
  /// `/HEAD` filter cannot see.
  public func remoteBranches(_ project: Project) async throws -> [String] {
    let output = try await git.run(
      ["for-each-ref", "--format=%(refname)", "refs/remotes"],
      in: project.path
    )
    let prefix = "refs/remotes/"
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.hasPrefix(prefix) && !$0.hasSuffix("/HEAD") }
      .map { String($0.dropFirst(prefix.count)) }
  }

  /// The `.git` directory shared by every worktree of the repository; where
  /// git records worktrees, so where to watch for them.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    let output = try await git.run(
      ["rev-parse", "--path-format=absolute", "--git-common-dir"], in: project.path)
    return URL(
      fileURLWithPath: output.trimmingCharacters(in: .whitespacesAndNewlines), isDirectory: true)
  }

  public func currentBranch(_ project: Project) async throws -> String {
    try await git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// `git worktree add [-b <branch>] <path> <start point>`.
  /// Pass `createBranch: false` to check out a branch that already exists.
  public func add(
    branch: String,
    at path: URL,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project
  ) async throws {
    var arguments = ["worktree", "add"]
    if createBranch { arguments += ["-b", branch] }
    arguments.append(path.path)
    arguments.append(createBranch ? (startPoint ?? "HEAD") : branch)
    _ = try await git.run(arguments, in: project.path)
  }

  public func remove(_ worktree: Worktree, force: Bool = false, in project: Project) async throws {
    var arguments = ["worktree", "remove"]
    if force { arguments.append("--force") }
    arguments.append(worktree.path.path)
    _ = try await git.run(arguments, in: project.path)
  }

  public func prune(_ project: Project) async throws {
    _ = try await git.run(["worktree", "prune"], in: project.path)
  }
}
