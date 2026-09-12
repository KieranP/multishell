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

  public init(path: String? = nil) throws {
    self.git = try GitRunner(executable: ExecutableLookup.find("git", path: path), path: path)
  }

  /// `--git-dir`, not `--is-inside-work-tree`, which prints `false` for a
  /// bare repository: a common layout for people who live in worktrees.
  public func isRepository(_ url: URL) async -> Bool {
    await git.succeeds(["rev-parse", "--git-dir"], in: url)
  }

  /// False for a freshly initialised repository. `HEAD` is unborn there, so
  /// nothing can be branched from it until the first commit.
  public func hasCommits(_ project: Project) async -> Bool {
    await git.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: project.path)
  }

  /// Every repository has at least its main worktree, so an empty list is
  /// git failing quietly; taken as a result it drops every tab.
  public func list(_ project: Project) async throws -> [Worktree] {
    let output = try await git.run(["worktree", "list", "--porcelain", "-z"], in: project.path)
    let worktrees = WorktreeListParser.parse(output, projectID: project.id)
    guard !worktrees.isEmpty else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "git listed no worktrees for \(project.path.path)")
    }
    return worktrees.map(Self.datedByDirectory)
  }

  /// git records no creation time, so the sidebar sorts by the directory's
  /// birth time, stamped on here to keep the parser off the filesystem.
  private static func datedByDirectory(_ worktree: Worktree) -> Worktree {
    var dated = worktree
    dated.createdAt = try? worktree.path.resourceValues(forKeys: [.creationDateKey]).creationDate
    return dated
  }

  /// The main worktree of the repository `url` is in, wherever in it `url`
  /// is: `git worktree list` puts that one first from anywhere.
  public func mainWorktree(containing url: URL) async throws -> URL {
    let output = try await git.run(["worktree", "list", "--porcelain", "-z"], in: url)
    guard let main = WorktreeListParser.parse(output, projectID: "").first else {
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "list"], status: 0,
        message: "no worktree listed for \(url.path)")
    }
    return main.path
  }

  /// `--no-optional-locks`: a plain `git status` takes `index.lock`, and this
  /// polls, so a `git commit` typed at the wrong moment would fail.
  public func status(of worktree: Worktree) async throws -> WorktreeStatus {
    let output = try await git.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "--branch"], in: worktree.path)
    return WorktreeStatusParser.parse(output)
  }

  /// Every branch with its tip, upstream and date, in one process, the date
  /// atom retried separately. `nil` is a failed read, not no branches.
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

  /// `git fetch --prune`, on the user's click only: the one git call here
  /// that talks to a network. `GIT_TERMINAL_PROMPT=0`, and a timeout.
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

  /// Remote branches with the symbolic `origin/HEAD` dropped. Full ref names,
  /// `%(refname:short)` abbreviating that one to `origin`.
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
