import Foundation
import MultishellCore
import MultishellProcess

/// Runs the per-project hooks from `ProjectSettings`, context through the
/// environment so a hook is a plain script; see Docs/design/hooks.md.
public enum WorktreeHooks {
  /// Returns at once when the stage's field is blank.
  static func run(
    _ stage: HookStage, for project: Project, worktreePath: URL, branch: String,
    shellPath: String? = nil, timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws {
    let command = Self.script(stage, in: project.settings)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return }

    let environment = HookVariable.environment(
      project: project, worktreePath: worktreePath, branch: branch)
    do {
      _ = try await ShellCommand().runScript(
        command, in: Self.directory(stage, project: project, worktreePath: worktreePath),
        environment: environment, shellPath: shellPath ?? ShellCatalogue.loginShellPath(),
        timeout: timeout, stopper: stopper)
    } catch {
      throw HookFailure(stage: stage, underlying: error)
    }
  }

  /// Whether a stage has anything to run; blank means no hook.
  public static func hasScript(_ stage: HookStage, in settings: ProjectSettings) -> Bool {
    !script(stage, in: settings).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private static func script(_ stage: HookStage, in settings: ProjectSettings) -> String {
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
    _ stage: HookStage, project: Project, worktreePath: URL
  ) -> URL {
    switch stage {
    case .preCreate, .postDelete: project.path
    case .postCreate: worktreePath
    case .preDelete:
      FileManager.default.fileExists(atPath: worktreePath.path) ? worktreePath : project.path
    }
  }
}
