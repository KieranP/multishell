import Foundation
import MultishellCore
import MultishellProcess

/// What the app calls: git operations plus the project's hooks, with the
/// project's settings deciding branch names and where worktrees live.
public struct WorktreeCoordinator: Sendable {
  let service: WorktreeService
  private let hooks: WorktreeHooks
  private let files: WorktreeFiles

  public init(
    service: WorktreeService, hooks: WorktreeHooks = WorktreeHooks(),
    files: WorktreeFiles = WorktreeFiles()
  ) {
    self.service = service
    self.hooks = hooks
    self.files = files
  }

  public init() throws {
    self.init(service: try WorktreeService())
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

  /// Statuses for many worktrees at once. A worktree whose status could not
  /// be read (deleted directory, git error) is simply absent from the result,
  /// and a bare repository, which has no working tree to ask about, is not
  /// asked.
  ///
  /// At most `maxConcurrentStatuses` run together. `git status` walks the
  /// working tree; thirty at once on a large checkout thrash the disk and
  /// take longer in total than a few at a time.
  public func statuses(of worktrees: [Worktree]) async -> [Worktree.ID: WorktreeStatus] {
    await withTaskGroup(of: (Worktree.ID, WorktreeStatus?).self) { group in
      var pending = worktrees.filter { !$0.isBare }.makeIterator()
      func startNext() {
        guard let worktree = pending.next() else { return }
        group.addTask { (worktree.id, try? await service.status(of: worktree)) }
      }
      for _ in 0..<Self.maxConcurrentStatuses { startNext() }

      var result: [Worktree.ID: WorktreeStatus] = [:]
      for await (id, status) in group {
        if let status { result[id] = status }
        startNext()
      }
      return result
    }
  }

  static let maxConcurrentStatuses = 8

  /// `git fetch --prune`, from the user's click; see `WorktreeService.fetch`.
  public func fetch(_ project: Project) async throws {
    try await service.fetch(project)
  }

  public func remoteBranches(_ project: Project) async throws -> [String] {
    try await service.remoteBranches(project)
  }

  /// Stable for the life of a project, so callers ask once and read the
  /// directories to watch and `WorktreeRecords` off it, with no process
  /// spawn per watcher tick.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    try await service.commonGitDirectory(project)
  }

  /// Directories whose contents change when worktrees are added, removed or
  /// switch branch: `.git/worktrees/` and each entry in it (where a linked
  /// worktree's `HEAD` lives). Until the first worktree exists that folder
  /// does not, so the common `.git` itself is watched for its creation.
  ///
  /// Never the common `.git` once `worktrees/` exists: `git status` rewrites
  /// `.git/index`, so watching the root turns every status poll into a
  /// spurious refresh. The main worktree's own branch switches are caught by
  /// the status poll instead.
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

  /// The directory a project should be identified by when the user picks
  /// `url`: the main worktree, so a subdirectory or a linked worktree does
  /// not become a second project listing the same worktrees.
  public func repositoryRoot(containing url: URL) async throws -> URL {
    try await service.mainWorktree(containing: url)
  }

  /// Where `create` would put a worktree for this branch, so the settings
  /// panel and the new-worktree sheet can show it before committing.
  /// `settings` is the project's effective value, defaults already applied.
  public func plannedPath(
    forBranch branch: String, createBranch: Bool = true, in project: Project,
    settings: WorktreeSettings
  ) -> URL {
    settings.worktreePath(
      forBranch: Self.branchName(branch, createBranch: createBranch, settings: settings),
      in: project)
  }

  /// The prefix is a naming convention for branches this app creates. An
  /// existing branch already has its name; prefixing it would ask git for a
  /// branch that does not exist.
  public static func branchName(
    _ raw: String, createBranch: Bool, settings: WorktreeSettings
  ) -> String {
    createBranch
      ? settings.qualifiedBranch(raw) : raw.trimmingCharacters(in: .whitespaces)
  }

  /// The pre-create hook and `git worktree add`. The post-create hook is
  /// `runPostCreate`, called separately so the app can show the worktree,
  /// and let the user move on, while a slow hook runs.
  ///
  /// A `HookFailure` here means nothing was created; one from `runPostCreate`
  /// means the worktree exists and only the hook went wrong. `shellPath` is
  /// the project's shell for its hooks, or `nil` for `$SHELL`. `onStep` is
  /// told as each stage starts, so a sheet can say which hook it is waiting
  /// on; a hook with no script is skipped without a step. `timeout` and
  /// `stopper` apply to the hooks, never to git; see `WorktreeHooks`.
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
    let path = settings.worktreePath(forBranch: branch, in: project)

    if WorktreeHooks.hasScript(project.settings.preCreateHook) { onStep?(.preCreateHook) }
    try await hooks.runPreCreate(
      for: project, worktreePath: path, branch: branch, shellPath: shellPath, timeout: timeout,
      stopper: stopper)
    onStep?(.addingWorktree)
    try FileManager.default.createDirectory(
      at: path.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try await service.add(
      branch: branch,
      at: path,
      basedOn: startPoint,
      createBranch: createBranch,
      in: project
    )
    return path
  }

  /// Links or copies the project's listed files into a worktree git has
  /// just made, before the post-create hook runs, so a hook and the first
  /// terminal both find them. Throws `WorktreeFileFailure` for what it
  /// could not place, or `WorktreeFilesStopped` if `stopper` was used part
  /// way through; the worktree is created either way. Returns at once when
  /// that list is blank.
  public func placeFiles(
    _ placement: WorktreePlacement, for project: Project, into worktreePath: URL,
    stopper: ProcessStopper? = nil
  ) throws {
    try files.place(
      placement.paths(in: project.settings), as: placement, from: project.path,
      to: worktreePath, isStopped: { stopper?.isStopped == true })
  }

  /// The other half of a create. Returns at once when the hook is blank.
  public func runPostCreate(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil,
    timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws {
    try await hooks.runPostCreate(
      for: project, worktreePath: worktreePath, branch: branch, shellPath: shellPath,
      timeout: timeout, stopper: stopper)
  }

  /// Runs the pre-delete hook, hands the worktree directory to `trash`,
  /// prunes its record, then runs the post-delete hook. The pre hook runs
  /// before every attempt and its veto stands.
  ///
  /// `trash` is the platform's Trash, so a worktree with uncommitted work
  /// is recoverable rather than unlinked; the directory is only pruned once
  /// it has taken the directory, and a `trash` that throws is a
  /// `TrashFailure` with nothing pruned. A directory already gone is only
  /// pruned. A locked worktree is unlocked first, since prune skips locked
  /// records.
  ///
  /// `deletingBranch` deletes the worktree's branch last, after the post
  /// hook, so a hook that pushes it still finds it, and a hook that fails
  /// keeps it. `git branch -d` refuses a branch with commits nothing else
  /// has; that is reported as a `BranchDeletionFailure`, with the worktree
  /// already gone, for the caller to offer `deleteBranch(force:)`.
  ///
  /// `onStep` is told as each stage starts, hook stages only when the hook
  /// has a script, so the detail pane can say what the worktree is waiting
  /// on. `timeout` and `stopper` apply to the hooks.
  public func remove(
    _ worktree: Worktree, deletingBranch: Bool = false, in project: Project,
    shellPath: String? = nil, trash: @Sendable (URL) async throws -> Void,
    timeout: Duration? = nil, stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil
  ) async throws {
    let path = worktree.path
    let branch = worktree.branch ?? worktree.head
    if WorktreeHooks.hasScript(project.settings.preDeleteHook) { onStep?(.preDeleteHook) }
    try await hooks.runPreDelete(
      for: project, worktreePath: path, branch: branch, shellPath: shellPath, timeout: timeout,
      stopper: stopper)
    onStep?(.removingWorktree)
    if worktree.isLocked { try await service.unlock(worktree, in: project) }
    if FileManager.default.fileExists(atPath: path.path) {
      do {
        try await trash(path)
      } catch {
        throw TrashFailure(path: path, underlying: error)
      }
    }
    try await service.prune(project)
    if WorktreeHooks.hasScript(project.settings.postDeleteHook) { onStep?(.postDeleteHook) }
    try await hooks.runPostDelete(
      for: project, worktreePath: path, branch: branch, shellPath: shellPath, timeout: timeout,
      stopper: stopper)
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
