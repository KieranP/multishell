import Foundation
import MultishellCore

/// What the app calls: git operations plus the project's hooks, with the
/// project's settings deciding branch names and where worktrees live.
public struct WorktreeCoordinator: Sendable {
  /// The reads that are git's answer alone; what stays here adds hooks,
  /// settings or a fan-out.
  public let git: WorktreeGit

  init(git: WorktreeGit) {
    self.git = git
  }

  /// The git on the process's own PATH, which from the Finder is the system directories
  /// alone; `resolved(searchPath:replacing:)` replaces it once the login shell's is known.
  public init() throws {
    self.init(git: WorktreeGit(runner: try GitRunner()))
  }

  /// The git on `searchPath`, the login shell's PATH, past Apple's git shim to the git it
  /// would run. Async, as it may ask xcrun; for the login environment's capture, not launch.
  public static func resolved(
    searchPath: String?,
    replacing previous: Self?,
  ) async throws -> Self {
    let executable = await GitExecutable.resolve(
      searchPath: searchPath,
      developerDirectory: await runOnDispatch { GitExecutable.selectedDeveloperDirectory() },
    )
    let runner = try GitRunner(
      executable: executable,
      searchPath: searchPath,
      runLog: previous?.git.runLog ?? GitRunLog(),
    )
    // Reads still in flight on the previous git hold slots the new one must count.
    guard let previous else { return Self(git: WorktreeGit(runner: runner)) }
    return Self(
      git: WorktreeGit(
        runner: runner,
        settlesNewIndex: previous.git.settlesNewIndex,
        readState: previous.git.readState,
      )
    )
  }
}
