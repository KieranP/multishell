import Foundation
import MultishellCore
import MultishellProcess

/// What the app calls: git operations plus the project's hooks, with the
/// project's settings deciding branch names and where worktrees live.
public struct WorktreeCoordinator: Sendable {
  let service: WorktreeService
  private let hooks: WorktreeHooks
  private let files: WorktreeFiles

  init(
    service: WorktreeService, hooks: WorktreeHooks = WorktreeHooks(),
    files: WorktreeFiles = WorktreeFiles()
  ) {
    self.service = service
    self.hooks = hooks
    self.files = files
  }

  /// `path` is the login shell's PATH. Without one the lookup sees the
  /// process's own, which from the Finder is the system directories alone.
  public init(path: String? = nil) throws {
    self.init(service: try WorktreeService(path: path))
  }

  /// As `init(path:)`, past Apple's git shim to the git it would run. Async,
  /// as it may ask xcrun; for the login environment's capture, not launch.
  public static func resolved(
    path: String?, replacing previous: WorktreeCoordinator? = nil
  ) async throws -> WorktreeCoordinator {
    let executable = await GitExecutable.resolve(path: path)
    let git = try GitRunner(executable: executable, path: path)
    return WorktreeCoordinator(service: previous?.service.running(git) ?? WorktreeService(git: git))
  }

  public func refresh(_ project: Project) async throws -> [Worktree] {
    try await service.list(project)
  }

  public func hasCommits(_ project: Project) async -> Bool {
    await service.hasCommits(project)
  }

  public func localBranches(_ project: Project) async throws -> [String] {
    try await service.localBranches(project)
  }

  public func currentBranch(_ project: Project) async throws -> String {
    try await service.currentBranch(project)
  }

  /// Statuses for many worktrees at once, each with how long git took, one
  /// that could not be read simply absent. At most `maxConcurrentStatuses` run together.
  public func readStatuses(
    of worktrees: [Worktree], counting indicator: GitStatusIndicator = .default
  ) async -> [Worktree.ID: StatusReading] {
    await withTaskGroup(of: (Worktree.ID, StatusReading?).self) { group in
      var pending = worktrees.filter { !$0.isBare }.makeIterator()
      func startNext() {
        guard let worktree = pending.next() else { return }
        group.addTask {
          let started = ContinuousClock.now
          guard let status = try? await service.status(of: worktree, counting: indicator)
          else {
            return (worktree.id, nil)
          }
          return (worktree.id, StatusReading(status: status, took: started.duration(to: .now)))
        }
      }
      for _ in 0..<Self.maxConcurrentStatuses { startNext() }

      var result: [Worktree.ID: StatusReading] = [:]
      for await (id, reading) in group {
        if let reading { result[id] = reading }
        startNext()
      }
      return result
    }
  }

  static let maxConcurrentStatuses = 8

  /// Drops what the status reads remember about worktrees that have gone.
  public func forgetStatusReads(of ids: [Worktree.ID]) {
    service.untrackedMemo.forget(directories: ids)
  }

  /// `git fetch --prune`, from the user's click; see `WorktreeService.fetch`.
  public func fetch(_ project: Project) async throws {
    try await service.fetch(project)
  }

  public func remoteBranches(_ project: Project) async throws -> [String] {
    try await service.remoteBranches(project)
  }

  /// Stable for the life of a project, so the watcher and the records check
  /// run off it with no process spawn per tick.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    try await service.commonGitDirectory(project)
  }

  /// Directories that change when worktrees do. Never the common `.git` once
  /// `worktrees/` exists; see Docs/design/worktrees.md.
  public static func directoriesToWatch(in common: URL) -> [URL] {
    let worktrees = common.appendingPathComponent("worktrees", isDirectory: true)
    guard FileManager.default.fileExists(atPath: worktrees.path) else { return [common] }
    let entries =
      (try? FileManager.default.contentsOfDirectory(at: worktrees, includingPropertiesForKeys: nil))
      ?? []
    return [worktrees] + entries.filter { FileManager.default.fileExists(atPath: $0.path) }
  }

  public func isRepository(_ url: URL) async -> Bool {
    await service.isRepository(url)
  }

  /// The directory a project is identified by: the main worktree, so a
  /// subdirectory does not become a second project.
  public func repositoryRoot(containing url: URL) async throws -> URL {
    try await service.mainWorktree(containing: url)
  }

  /// Where `create` would put a worktree for this branch, so the sheet can
  /// show it first. `settings` is the project's effective value.
  public func plannedPath(
    forBranch branch: String, createBranch: Bool = true, in project: Project,
    settings: WorktreeSettings
  ) -> URL {
    settings.worktreePath(
      forBranch: Self.branchName(branch, createBranch: createBranch, settings: settings),
      in: project)
  }

  /// The prefix names branches this app creates. An existing branch has its
  /// name already, and prefixing it would ask git for one that is not there.
  public static func branchName(
    _ raw: String, createBranch: Bool, settings: WorktreeSettings
  ) -> String {
    createBranch
      ? settings.qualifiedBranch(raw) : raw.trimmingCharacters(in: .whitespaces)
  }

  /// The pre-create hook and `git worktree add`, `runPostCreate` being
  /// separate so a slow hook does not hold the sheet. See hooks.md.
  @discardableResult
  public func add(
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
    let branch = Self.branchName(rawBranch, createBranch: createBranch, settings: settings)
    // Before the hook, for an existing branch too: git rejects the name at
    // the end of it, and the hook's work is done by then.
    guard GitRefName.isValidBranch(branch) else { throw InvalidBranchName(branch) }
    // The one place the path is derived, so what the sheet showed and what
    // the model holds back from `git status` cannot part from what is made.
    let path = plannedPath(
      forBranch: rawBranch, createBranch: createBranch, in: project, settings: settings)

    if WorktreeHooks.hasScript(.preCreate, in: project.settings) { onStep?(.preCreateHook) }
    try await hooks.run(
      .preCreate, for: project, worktreePath: path, branch: branch, shellPath: shellPath,
      timeout: timeout, stopper: stopper)
    onStep?(.addingWorktree)
    // No container directory made here: `git worktree add` makes the leading
    // directories itself, and a refused add then leaves none behind.
    let firstMade = Self.highestMissingAncestor(of: path)
    // Asked first: a stop can land before git has made anything, and the
    // name may be a branch of the user's that the add was refusing.
    let branchIsNew = createBranch ? await service.lacksBranch(branch, in: project) : false
    // An unforced remove still forgets a registered worktree whose directory is
    // away. Asked even where the path exists: git fills an empty directory.
    let madeHere = await !service.isListed(path, in: project)
    do {
      try await service.add(
        branch: branch,
        at: path,
        basedOn: startPoint,
        createBranch: createBranch,
        in: project,
        stopper: stopper
      )
    } catch  where stopper?.isStopped == true {
      await takeBack(
        path, madeHere: madeHere, branch: branchIsNew ? branch : nil, through: firstMade,
        in: project)
      throw error
    }
    await service.refreshIndex(of: path, stopper: stopper)
    // A Cancel during that wait comes after git finished; see worktrees.md.
    if stopper?.isStopped == true {
      await takeBack(
        path, madeHere: madeHere, branch: branchIsNew ? branch : nil, through: firstMade,
        in: project)
      throw ProcessFailure(
        executable: "git", arguments: ["worktree", "add"], status: 0,
        message: "stopped while the new index settled", stop: .stopped)
    }
    return path
  }

  /// A stopped add leaves its new branch and its directories, and the worktree
  /// where git had finished, so the same name could not be tried again.
  private func takeBack(
    _ path: URL, madeHere: Bool, branch: String?, through firstMade: URL?, in project: Project
  ) async {
    if madeHere { await service.removeUnchanged(path, in: project) }
    if let branch { await service.deleteBranchIfUnlisted(branch, in: project) }
    if let firstMade { Self.removeEmptyDirectories(from: path, through: firstMade) }
  }

  /// The topmost directory on the way to `path` that is not there yet.
  static func highestMissingAncestor(of path: URL) -> URL? {
    let (existing, unmade) = path.splitAtDeepestExisting()
    return unmade.first.map { existing.appendingPathComponent($0) }
  }

  /// Each directory from `path` up to `top` that holds nothing; one holding
  /// anything stops the walk, `removeItem` taking a directory whole.
  static func removeEmptyDirectories(from path: URL, through top: URL) {
    let manager = FileManager.default
    var directory = path.standardizedFileURL
    let last = top.standardizedFileURL.pathComponents.count
    while directory.pathComponents.count >= last {
      // `rmdir` refuses a directory with anything in it, a create beside this
      // one having perhaps made its checkout there since.
      if manager.fileExists(atPath: directory.path), rmdir(directory.path) != 0 { return }
      directory = directory.deletingLastPathComponent()
    }
  }

  /// Links or copies the project's listed files in before the post-create
  /// hook, so the hook and the first terminal both find them.
  @discardableResult
  public func placeFiles(
    _ list: WorktreeFileList, for project: Project, into worktreePath: URL,
    stopper: ProcessStopper? = nil
  ) throws -> [String] {
    try files.place(
      list.paths, as: list.placement, from: project.path, to: worktreePath,
      heldToRepository: list.heldToRepository, isStopped: { stopper?.isStopped == true }
    ).map(\.path)
  }

  /// The other half of a create. Returns at once when the hook is blank.
  public func runPostCreate(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil,
    timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws {
    try await hooks.run(
      .postCreate, for: project, worktreePath: worktreePath, branch: branch, shellPath: shellPath,
      timeout: timeout, stopper: stopper)
  }

  /// Pre-delete hook, the directory to `trash`, the record forgotten,
  /// post-delete hook, the branch last. See worktrees.md and hooks.md.
  public func remove(
    _ worktree: Worktree, deletingBranch: Bool = false, in project: Project,
    shellPath: String? = nil, trash: @Sendable (URL) async throws -> Void,
    timeout: Duration? = nil, stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil
  ) async throws {
    // The main worktree is the repository, `.git` and all, and the trash
    // step would bin it. Nothing below this guard checks.
    guard worktree.isRemovable else {
      throw NotAWorktree(path: worktree.path)
    }
    let path = worktree.path
    let branch = worktree.branch ?? worktree.head
    let isThere = FileManager.default.fileExists(atPath: path.path)
    // Whatever took a stale record's path since is not ours: not trashed,
    // and no hook runs, each being handed that path; see worktrees.md.
    if isThere, try await !service.isCheckout(of: worktree, in: project) {
      onStep?(.removingWorktree)
      try await service.forgetStale(worktree, in: project)
    } else {
      if WorktreeHooks.hasScript(.preDelete, in: project.settings) { onStep?(.preDeleteHook) }
      try await hooks.run(
        .preDelete, for: project, worktreePath: path, branch: branch, shellPath: shellPath,
        timeout: timeout, stopper: stopper)
      onStep?(.removingWorktree)
      if isThere {
        do {
          try await trash(path)
        } catch {
          throw TrashFailure(path: path, underlying: error)
        }
        // `forget` would unlink a directory still here; only the Trash may take it.
        guard !FileManager.default.fileExists(atPath: path.path) else {
          throw TrashFailure(path: path, underlying: TrashTookNothing())
        }
      }
      try await service.forget(worktree, in: project)
      if WorktreeHooks.hasScript(.postDelete, in: project.settings) { onStep?(.postDeleteHook) }
      try await hooks.run(
        .postDelete, for: project, worktreePath: path, branch: branch, shellPath: shellPath,
        timeout: timeout, stopper: stopper)
    }
    if deletingBranch, let branch = worktree.branch {
      onStep?(.deletingBranch)
      try await deleteBranch(branch, in: project)
    }
  }

  public func deleteBranch(_ branch: String, force: Bool = false, in project: Project) async throws
  {
    do {
      try await service.deleteBranch(branch, force: force, in: project)
    } catch {
      throw BranchDeletionFailure(branch: branch, underlying: error)
    }
  }
}
