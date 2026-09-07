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

  /// Every local and remote branch with its tip, the upstream a local one
  /// tracks and whether that upstream is still there. One process for the
  /// whole repository; see `BranchRefParser` for the format.
  public func branchRefs(_ project: Project) async -> [BranchRef] {
    let format = [
      "%(refname)", "%(objectname)", "%(upstream)", "%(upstream:track)", "%(symref)",
    ]
    let output = await git.output(
      [
        "for-each-ref", "--format=" + format.joined(separator: "%09"), "refs/heads", "refs/remotes",
      ],
      in: project.path)
    return BranchRefParser.parse(output ?? "")
  }

  /// The branches `base` can reach: merged into it by a merge commit or a
  /// fast-forward. One process answers for every branch in the repository,
  /// which is why the check starts here rather than with a `merge-base` per
  /// worktree.
  /// `nil` where git could not answer, which is not the same as "none":
  /// taken as an answer it would be cached as a confident "not merged"
  /// until the branch next moved.
  public func mergedBranches(into base: String, in project: Project) async -> Set<String>? {
    guard
      let output = await git.output(
        ["branch", "--merged", base, "--format=%(refname:short)"], in: project.path)
    else { return nil }
    return MergedBranchParser.parse(output)
  }

  /// Whether `branch` has moved since it was created, from the number of
  /// entries in its reflog: `git worktree add -b` cuts a branch at the
  /// commit it starts from and writes one entry, and every commit made on
  /// it writes another.
  ///
  /// This is what tells a branch that has landed from one that never left.
  /// Both are reachable from the default branch, and no amount of ancestry
  /// separates them: a new worktree's branch is an ancestor of the trunk
  /// from the moment it exists.
  ///
  /// `nil` where the reflog cannot answer, so the caller can fall back: a
  /// bare repository keeps no reflog unless asked, and entries expire.
  public func branchHasMoved(_ branch: String, in project: Project) async -> Bool? {
    let output = await git.output(
      ["rev-list", "--walk-reflogs", "--count", branch], in: project.path)
    guard let text = output?.trimmingCharacters(in: .whitespacesAndNewlines),
      let entries = Int(text), entries > 0
    else { return nil }
    return entries > 1
  }

  /// Whether `base` already has an equivalent patch for every commit on
  /// `branch`: how a rebase-merge or a run of cherry-picks lands, which no
  /// ancestry test can see. Costs a patch id per commit on the branch, so
  /// it is asked only about branches `mergedBranches` did not name.
  public func isPatchEquivalent(
    _ branch: String, against base: String, in project: Project
  ) async -> Bool {
    guard let output = await git.output(["cherry", base, branch], in: project.path) else {
      return false
    }
    return PatchEquivalenceParser.parse(output)
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
