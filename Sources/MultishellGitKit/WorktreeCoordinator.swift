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

  /// Creates the worktree, then runs the post-create hook. A `HookFailure`
  /// means the worktree exists and only the hook went wrong.
  @discardableResult
  public func create(
    branch rawBranch: String,
    basedOn startPoint: String? = nil,
    createBranch: Bool = true,
    in project: Project,
    settings: WorktreeSettings
  ) async throws -> URL {
    let branch = Self.branchName(rawBranch, createBranch: createBranch, settings: settings)
    let path = settings.worktreePath(forBranch: branch, in: project)

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
    try await hooks.runPostCreate(for: project, worktreePath: path, branch: branch)
    return path
  }

  /// Removes the worktree, then runs the post-delete hook.
  ///
  /// A worktree whose directory is already gone cannot be removed, only
  /// pruned: `git worktree remove` refuses with "does not exist". Prune is
  /// what the user meant in that case, and the hook still runs.
  public func remove(_ worktree: Worktree, force: Bool = false, in project: Project) async throws {
    let path = worktree.path
    let branch = worktree.branch ?? worktree.head
    if FileManager.default.fileExists(atPath: path.path) {
      try await service.remove(worktree, force: force, in: project)
    } else {
      try await service.prune(project)
    }
    try await hooks.runPostDelete(for: project, worktreePath: path, branch: branch)
  }
}
