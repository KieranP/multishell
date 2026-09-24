import Foundation
import MultishellCore
import MultishellProcess

/// Runs the per-project hooks from `ProjectSettings`, context through the
/// environment so a hook is a plain script; see Docs/design/hooks.md.
public struct WorktreeHooks: Sendable {
  private let shell: ShellCommand

  public init(shell: ShellCommand = ShellCommand()) {
    self.shell = shell
  }

  /// Returns at once when the stage's field is blank.
  public func run(
    _ stage: HookFailure.Stage, for project: Project, worktreePath: URL, branch: String,
    shellPath: String? = nil, timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws {
    let command = Self.script(stage, in: project.settings)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return }

    let environment = HookVariable.environment(
      project: project, worktreePath: worktreePath, branch: branch)
    do {
      _ = try await shell.runScript(
        command, in: Self.directory(stage, project: project, worktreePath: worktreePath),
        environment: environment, shellPath: shellPath, timeout: timeout, stopper: stopper)
    } catch {
      throw HookFailure(stage: stage, underlying: error)
    }
  }

  /// Whether a stage has anything to run; blank means no hook.
  public static func hasScript(_ stage: HookFailure.Stage, in settings: ProjectSettings) -> Bool {
    !script(stage, in: settings).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private static func script(_ stage: HookFailure.Stage, in settings: ProjectSettings) -> String {
    switch stage {
    case .preCreate: settings.preCreateHook
    case .postCreate: settings.postCreateHook
    case .preDelete: settings.preDeleteHook
    case .postDelete: settings.postDeleteHook
    }
  }

  /// In the worktree where it exists at that stage, in the repository where
  /// it does not; see Docs/design/hooks.md.
  private static func directory(
    _ stage: HookFailure.Stage, project: Project, worktreePath: URL
  ) -> URL {
    switch stage {
    case .preCreate, .postDelete: project.path
    case .postCreate: worktreePath
    case .preDelete:
      FileManager.default.fileExists(atPath: worktreePath.path) ? worktreePath : project.path
    }
  }
}

/// Raised when a hook fails. A pre hook's failure means the operation was
/// never asked for; a post hook's means it has already succeeded.
public struct HookFailure: Error, CustomStringConvertible {
  public enum Stage: String, Sendable {
    case preCreate
    case postCreate
    case preDelete
    case postDelete

    /// Whether the git operation the hook surrounds has happened.
    public var operationHappened: Bool {
      self == .postCreate || self == .postDelete
    }
  }

  public let stage: Stage
  public let underlying: any Error

  public init(stage: Stage, underlying: any Error) {
    self.stage = stage
    self.underlying = underlying
  }

  public var description: String {
    "\(stage.rawValue) hook failed: \(underlying)"
  }

  /// Why the hook did not finish on its own, when it did not: the timeout,
  /// or the user's stop.
  public var stop: ProcessStop? {
    (underlying as? ProcessFailure)?.stop
  }
}
