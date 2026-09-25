import Foundation

/// What the app calls: git operations plus the project's hooks, with the
/// project's settings deciding branch names and where worktrees live.
public struct WorktreeCoordinator: Sendable {
  /// The reads that are git's answer alone; what stays here adds hooks,
  /// settings or a fan-out.
  public let git: WorktreeGit

  init(git: WorktreeGit) {
    self.git = git
  }

  /// `searchPath` is the login shell's PATH. Without one the lookup sees the
  /// process's own, which from the Finder is the system directories alone.
  public init(searchPath: String? = nil) throws {
    self.init(git: try WorktreeGit(searchPath: searchPath))
  }

  /// As `init(searchPath:)`, past Apple's git shim to the git it would run. Async,
  /// as it may ask xcrun; for the login environment's capture, not launch.
  public static func resolved(
    searchPath: String?, replacing previous: WorktreeCoordinator? = nil
  ) async throws -> WorktreeCoordinator {
    let executable = await GitExecutable.resolve(searchPath: searchPath)
    let runner = try GitRunner(executable: executable, searchPath: searchPath)
    // Reads still in flight on the previous git hold slots the new one must count.
    guard let previous else { return WorktreeCoordinator(git: WorktreeGit(runner: runner)) }
    return WorktreeCoordinator(
      git: WorktreeGit(
        runner: runner, settlesNewIndex: previous.git.settlesNewIndex,
        shared: previous.git.shared))
  }
}
