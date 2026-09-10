import Foundation
import MultishellCore
import MultishellProcess

/// The git side of worktree management. Knows nothing about hooks or settings.
public struct WorktreeService: Sendable {
  /// Internal rather than private so the merge reads, which are their own
  /// file, can run through the same runner.
  let git: GitRunner

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
    return worktrees.map(Self.datedByDirectory)
  }

  /// git records no creation time for a worktree, so the date the sidebar
  /// sorts by is the birth time of the directory `git worktree add` made.
  /// The parser stays free of the filesystem, so it is stamped on here.
  ///
  /// `nil` where the filesystem keeps no birth time, or the directory is
  /// gone: that orders the worktree last rather than first, which is what a
  /// date nobody knows deserves.
  private static func datedByDirectory(_ worktree: Worktree) -> Worktree {
    var dated = worktree
    dated.createdAt = try? worktree.path.resourceValues(forKeys: [.creationDateKey]).creationDate
    return dated
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

  /// Every local and remote branch with its tip, the upstream a local one
  /// tracks, whether that upstream is still there, and when it was last
  /// committed to. One process for the whole repository; see
  /// `BranchRefParser` for the format.
  /// The date atom is asked for separately from the rest: git fails the
  /// whole query on a format atom it does not know, and the merged badges
  /// read this too. Without the second attempt, a git too old for
  /// `%(committerdate:unix)` would cost every badge as well as the order,
  /// silently, on every poll. The retry costs a process only where the
  /// first call already failed.
  ///
  /// `nil` where git could not answer, which is not the same as a repository
  /// with no branches: taken as one, every badge on the project would be
  /// dropped and every commit date the sidebar orders by blanked, on one bad
  /// read.
  public func branchRefs(_ project: Project) async -> [BranchRef]? {
    if let output = await git.output(Self.refQuery(withDates: true), in: project.path) {
      return BranchRefParser.parse(output)
    }
    guard let output = await git.output(Self.refQuery(withDates: false), in: project.path) else {
      return nil
    }
    return BranchRefParser.parse(output)
  }

  private static func refQuery(withDates: Bool) -> [String] {
    var format = [
      "%(refname)", "%(objectname)", "%(upstream)", "%(upstream:track)", "%(symref)",
    ]
    if withDates { format.append("%(committerdate:unix)") }
    return [
      "for-each-ref", "--format=" + format.joined(separator: "%09"), "refs/heads", "refs/remotes",
    ]
  }

  /// `git fetch --prune`, so what a branch has been merged into is asked of
  /// a remote as it is now, and an upstream deleted on the merge is seen to
  /// be gone.
  ///
  /// The user's click only, never a poll: it is the one git call here that
  /// talks to a network. `GIT_TERMINAL_PROMPT=0` so a repository wanting a
  /// password fails instead of waiting on a terminal this app does not have,
  /// and a timeout for the ones that would hang before that.
  public func fetch(_ project: Project, timeout: Duration = .seconds(120)) async throws {
    _ = try await git.run(
      ["fetch", "--prune", "--quiet"], in: project.path,
      environment: ["GIT_TERMINAL_PROMPT": "0"], timeout: timeout)
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
