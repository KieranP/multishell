import Foundation
import MultishellCore
import MultishellProcess

/// Raised when a hook fails. The git operation around it has already
/// succeeded, so callers should report this without rolling anything back.
public struct HookFailure: Error, CustomStringConvertible {
  public enum Stage: String, Sendable {
    case postCreate
    case postDelete
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
/// arguments, so a hook is a plain command line with nothing to quote.
public struct WorktreeHooks: Sendable {
  private let shell: ShellCommand

  public init(shell: ShellCommand = ShellCommand()) {
    self.shell = shell
  }

  public func runPostCreate(for project: Project, worktreePath: URL, branch: String) async throws {
    try await run(
      project.settings.postCreateHook,
      stage: .postCreate,
      in: worktreePath,
      project: project,
      worktreePath: worktreePath,
      branch: branch
    )
  }

  /// Runs in the repository, because the worktree directory is gone by now.
  public func runPostDelete(for project: Project, worktreePath: URL, branch: String) async throws {
    try await run(
      project.settings.postDeleteHook,
      stage: .postDelete,
      in: project.path,
      project: project,
      worktreePath: worktreePath,
      branch: branch
    )
  }

  private func run(
    _ commandLine: String,
    stage: HookFailure.Stage,
    in directory: URL,
    project: Project,
    worktreePath: URL,
    branch: String
  ) async throws {
    let command = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return }

    let environment = [
      "MULTISHELL_PROJECT_PATH": project.path.path,
      "MULTISHELL_PROJECT_NAME": project.name,
      "MULTISHELL_WORKTREE_PATH": worktreePath.path,
      "MULTISHELL_BRANCH": branch,
    ]
    do {
      _ = try await shell.run(command, in: directory, environment: environment)
    } catch {
      throw HookFailure(stage: stage, underlying: error)
    }
  }
}
