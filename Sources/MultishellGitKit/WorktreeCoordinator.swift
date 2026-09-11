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

  /// `path` is the login shell's PATH. Without one the lookup sees the
  /// process's own, which from the Finder is the system directories alone.
  public init(path: String? = nil) throws {
    self.init(service: try WorktreeService(path: path))
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

  /// Statuses for many worktrees at once, one that could not be read simply
  /// absent. At most `maxConcurrentStatuses` run together.
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

  /// Stable for the life of a project, so the watcher and the records check
  /// run off it with no process spawn per tick.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    try await service.commonGitDirectory(project)
  }

  /// Directories that change when worktrees do. Never the common `.git` once
  /// `worktrees/` exists; see docs/design/worktrees.md.
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

  /// Links or copies the project's listed files in before the post-create
  /// hook, so the hook and the first terminal both find them.
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

  /// Pre-delete hook, the directory to `trash`, prune, post-delete hook, the
  /// branch last. See docs/design/worktrees.md and docs/design/hooks.md.
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
