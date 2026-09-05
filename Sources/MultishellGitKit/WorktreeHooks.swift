import Foundation
import MultishellCore
import MultishellProcess

/// Raised when a hook fails. A pre hook's failure means the git operation
/// was never asked for; a post hook's means it has already succeeded, so
/// callers report those without rolling anything back.
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
}

/// Runs the per-project hooks from `ProjectSettings`.
///
/// Hooks receive their context through the environment rather than as
/// arguments, so a hook is a plain script with nothing to quote. Each runs
/// as one script through the project's shell, the one its tabs get, as an
/// interactive login shell, stopping at its first failing line where the
/// shell can be told to (`ShellCommand.runScript`). `shellPath` nil means
/// `$SHELL`.
public struct WorktreeHooks: Sendable {
  private let shell: ShellCommand

  public init(shell: ShellCommand = ShellCommand()) {
    self.shell = shell
  }

  /// Runs in the repository; the worktree does not exist yet.
  public func runPreCreate(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil
  ) async throws {
    try await run(
      project.settings.preCreateHook,
      stage: .preCreate,
      in: project.path,
      project: project,
      worktreePath: worktreePath,
      branch: branch,
      shellPath: shellPath
    )
  }

  public func runPostCreate(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil
  ) async throws {
    try await run(
      project.settings.postCreateHook,
      stage: .postCreate,
      in: worktreePath,
      project: project,
      worktreePath: worktreePath,
      branch: branch,
      shellPath: shellPath
    )
  }

  /// Runs in the worktree while it is still there; in the repository when
  /// the directory is already gone and only the record is being pruned.
  public func runPreDelete(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil
  ) async throws {
    let exists = FileManager.default.fileExists(atPath: worktreePath.path)
    try await run(
      project.settings.preDeleteHook,
      stage: .preDelete,
      in: exists ? worktreePath : project.path,
      project: project,
      worktreePath: worktreePath,
      branch: branch,
      shellPath: shellPath
    )
  }

  /// Runs in the repository, because the worktree directory is gone by now.
  public func runPostDelete(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil
  ) async throws {
    try await run(
      project.settings.postDeleteHook,
      stage: .postDelete,
      in: project.path,
      project: project,
      worktreePath: worktreePath,
      branch: branch,
      shellPath: shellPath
    )
  }

  private func run(
    _ script: String,
    stage: HookFailure.Stage,
    in directory: URL,
    project: Project,
    worktreePath: URL,
    branch: String,
    shellPath: String?
  ) async throws {
    let command = script.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return }

    let environment = [
      "MULTISHELL_PROJECT_PATH": project.path.path,
      "MULTISHELL_PROJECT_NAME": project.name,
      "MULTISHELL_WORKTREE_PATH": worktreePath.path,
      "MULTISHELL_BRANCH": branch,
    ]
    do {
      _ = try await shell.runScript(
        command, in: directory, environment: environment, shellPath: shellPath)
    } catch {
      throw HookFailure(stage: stage, underlying: error)
    }
  }
}
