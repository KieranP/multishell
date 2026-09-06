import Foundation
import MultishellCore

/// What the app calls: git operations plus the project's hooks, with the
/// project's settings deciding branch names and where worktrees live.
public struct WorktreeCoordinator: Sendable {
  private let service: WorktreeService
  private let hooks: WorktreeHooks

  public init(service: WorktreeService, hooks: WorktreeHooks = WorktreeHooks()) {
    self.service = service
    self.hooks = hooks
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
  /// be read (deleted directory, git error) is simply absent from the result.
  ///
  /// At most `maxConcurrentStatuses` run together. `git status` walks the
  /// working tree; thirty at once on a large checkout thrash the disk and
  /// take longer in total than a few at a time.
  public func statuses(of worktrees: [Worktree]) async -> [Worktree.ID: WorktreeStatus] {
    await withTaskGroup(of: (Worktree.ID, WorktreeStatus?).self) { group in
      var pending = worktrees.makeIterator()
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

  public func remoteBranches(_ project: Project) async throws -> [String] {
    try await service.remoteBranches(project)
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
  public func directoriesToWatch(for project: Project) async -> [URL] {
    guard let common = try? await service.commonGitDirectory(project) else { return [] }
    return Self.directoriesToWatch(in: common)
  }

  /// Stable for the life of a project, so callers may cache it and use the
  /// pure `directoriesToWatch(in:)` and `WorktreeRecords.read` without a
  /// process spawn per watcher tick.
  public func commonGitDirectory(_ project: Project) async throws -> URL {
    try await service.commonGitDirectory(project)
  }

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

  /// Runs the pre-create hook, creates the worktree, then runs the
  /// post-create hook. A `HookFailure` from the pre stage means nothing was
  /// created; from the post stage, that the worktree exists and only the
  /// hook went wrong. `shellPath` is the project's shell for its hooks, or
  /// `nil` for `$SHELL`. `onStep` is told as each stage starts, so a sheet
  /// can say which hook it is waiting on; a hook with no script is skipped
  /// without a step.
  @discardableResult
  public func create(
    branch rawBranch: String,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    settings: WorktreeSettings,
    shellPath: String? = nil,
    onStep: (@Sendable (WorktreeCreationStep) -> Void)? = nil
  ) async throws -> URL {
    let path = try await add(
      branch: rawBranch, basedOn: startPoint, createBranch: createBranch, in: project,
      settings: settings, shellPath: shellPath, onStep: onStep)
    let branch = Self.branchName(rawBranch, createBranch: createBranch, settings: settings)
    if WorktreeHooks.hasScript(project.settings.postCreateHook) { onStep?(.postCreateHook) }
    try await runPostCreate(for: project, worktreePath: path, branch: branch, shellPath: shellPath)
    return path
  }

  /// The first half of `create`: the pre-create hook and `git worktree add`.
  /// The post-create hook is `runPostCreate`, kept apart so the app can show
  /// the worktree, and let the user move on, while a slow hook runs.
  @discardableResult
  public func add(
    branch rawBranch: String,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    settings: WorktreeSettings,
    shellPath: String? = nil,
    onStep: (@Sendable (WorktreeCreationStep) -> Void)? = nil
  ) async throws -> URL {
    let branch = Self.branchName(rawBranch, createBranch: createBranch, settings: settings)
    let path = settings.worktreePath(forBranch: branch, in: project)

    if WorktreeHooks.hasScript(project.settings.preCreateHook) { onStep?(.preCreateHook) }
    try await hooks.runPreCreate(
      for: project, worktreePath: path, branch: branch, shellPath: shellPath)
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

  /// The second half of `create`. Returns at once when the hook is blank.
  public func runPostCreate(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil
  ) async throws {
    try await hooks.runPostCreate(
      for: project, worktreePath: worktreePath, branch: branch, shellPath: shellPath)
  }

  /// Runs the pre-delete hook, removes the worktree, then runs the
  /// post-delete hook. The pre hook runs before every attempt, so a forced
  /// retry after git refused asks it again; its veto stands over the
  /// user's answer to git's refusal, which was about something else.
  ///
  /// A worktree whose directory is already gone cannot be removed, only
  /// pruned: `git worktree remove` refuses with "does not exist". Prune is
  /// what the user meant in that case, and the hooks still run.
  ///
  /// `deletingBranch` deletes the worktree's branch last, after the post
  /// hook, so a hook that pushes it still finds it, and a hook that fails
  /// keeps it. `git branch -d` refuses a branch with commits nothing else
  /// has; that is reported as a `BranchDeletionFailure`, with the worktree
  /// already gone, for the caller to offer `deleteBranch(force:)`.
  ///
  /// `onStep` is told as each stage starts, hook stages only when the hook
  /// has a script, so the detail pane can say what the worktree is waiting
  /// on.
  public func remove(
    _ worktree: Worktree, force: Bool = false, deletingBranch: Bool = false, in project: Project,
    shellPath: String? = nil, onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil
  ) async throws {
    let path = worktree.path
    let branch = worktree.branch ?? worktree.head
    if WorktreeHooks.hasScript(project.settings.preDeleteHook) { onStep?(.preDeleteHook) }
    try await hooks.runPreDelete(
      for: project, worktreePath: path, branch: branch, shellPath: shellPath)
    onStep?(.removingWorktree)
    if FileManager.default.fileExists(atPath: path.path) {
      try await service.remove(worktree, force: force, in: project)
    } else {
      try await service.prune(project)
    }
    if WorktreeHooks.hasScript(project.settings.postDeleteHook) { onStep?(.postDeleteHook) }
    try await hooks.runPostDelete(
      for: project, worktreePath: path, branch: branch, shellPath: shellPath)
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

/// The stages of a create, in order, for a sheet to show while it waits. A
/// hook stage is reported only when that hook has a script.
public enum WorktreeCreationStep: Sendable, Equatable {
  case preCreateHook
  case addingWorktree
  case postCreateHook
}

/// The stages of a remove, in order. A hook stage is reported only when that
/// hook has a script; the branch stage only when the branch is to go.
public enum WorktreeRemovalStep: Sendable, Equatable {
  case preDeleteHook
  case removingWorktree
  case postDeleteHook
  case deletingBranch

  /// Where a remove of this worktree under these settings starts, so a
  /// caller can show the first stage before the first report arrives.
  public static func first(for project: Project) -> WorktreeRemovalStep {
    WorktreeHooks.hasScript(project.settings.preDeleteHook) ? .preDeleteHook : .removingWorktree
  }
}

/// The worktree is gone but its branch is not: git refused to delete it,
/// usually because it has commits no other branch has.
public struct BranchDeletionFailure: Error, CustomStringConvertible {
  public let branch: String
  public let underlying: any Error

  public init(branch: String, underlying: any Error) {
    self.branch = branch
    self.underlying = underlying
  }

  public var description: String {
    "branch \(branch) was not deleted: \(underlying)"
  }
}
