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

  /// `--git-dir`, not `--is-inside-work-tree`: the latter prints `false`
  /// for a bare repository, and a bare clone with its worktrees beside it
  /// is a common layout for people who live in worktrees.
  public func isRepository(_ url: URL) async -> Bool {
    await git.succeeds(["rev-parse", "--git-dir"], in: url)
  }

  /// False for a freshly initialised repository. `HEAD` is unborn there, so
  /// nothing can be branched from it until the first commit.
  public func hasCommits(_ project: Project) async -> Bool {
    await git.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: project.path)
  }

  /// Every repository has at least its main worktree, so an empty list is
  /// git failing quietly, not a result; taken as one it would drop every tab
  /// of the project.
  public func list(_ project: Project) async throws -> [Worktree] {
    let output = try await git.run(["worktree", "list", "--porcelain"], in: project.path)
    let worktrees = WorktreeListParser.parse(output, projectID: project.id)
    guard !worktrees.isEmpty else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "git listed no worktrees for \(project.path.path)")
    }
    return worktrees
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

  /// `--no-optional-locks`: a plain `git status` refreshes the index and
  /// takes `index.lock` to write it back. This runs in the background every
  /// few seconds, so without the flag a `git commit` typed in a terminal at
  /// the wrong moment fails with "index.lock exists". It also means a poll
  /// never rewrites the index the watcher's directories contain.
  public func status(of worktree: Worktree) async throws -> WorktreeStatus {
    let output = try await git.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "--branch"], in: worktree.path)
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

  /// `git worktree prune` leaves a locked record alone, so a locked worktree
  /// is unlocked before its directory goes.
  public func unlock(_ worktree: Worktree, in project: Project) async throws {
    _ = try await git.run(["worktree", "unlock", worktree.path.path], in: project.path)
  }

  /// Forgets every record whose directory is gone.
  public func prune(_ project: Project) async throws {
    _ = try await git.run(["worktree", "prune"], in: project.path)
  }

  /// `git branch -d`, which refuses a branch with commits no other branch
  /// has; `force` is `-D`.
  public func deleteBranch(_ branch: String, force: Bool = false, in project: Project) async throws
  {
    _ = try await git.run(["branch", force ? "-D" : "-d", branch], in: project.path)
  }
}
