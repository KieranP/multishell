import Foundation
import MultishellCore

/// The alerts the model raises itself, rather than from an error. In one
/// place so the wording is tested and shared by every frontend.
extension PresentedError {
  public static func notARepository(_ url: URL) -> PresentedError {
    PresentedError(
      title: "Not a git repository",
      message: "\(url.lastPathComponent) has no .git directory, or git could not read it.")
  }

  /// A shell spawned in a missing directory silently lands in $HOME, which
  /// is worse than an honest refusal.
  public static func worktreeDirectoryMissing(_ path: String) -> PresentedError {
    PresentedError(
      title: "Worktree directory is missing",
      message:
        "\(path) does not exist. If it was deleted by hand, remove the worktree to let git prune it."
    )
  }

  public static var noAgentChosen: PresentedError {
    PresentedError(
      title: "No agent chosen",
      message: "Pick a preferred agent in Settings > Agents, or in this project's settings.")
  }

  /// The tab has already opened as a plain shell by the time this shows.
  public static func agentNotInstalled(_ name: String) -> PresentedError {
    PresentedError(
      title: "\(name) is not installed",
      message:
        "The tab opened as a plain shell. Install \(name), or choose another agent in Settings > Agents, then use Refresh."
    )
  }

  public static var noEditorChosen: PresentedError {
    PresentedError(
      title: "No editor chosen", message: "Pick a preferred editor in Settings > General.")
  }

  public static var noEditorCommand: PresentedError {
    PresentedError(
      title: "No editor command",
      message: "Type the command in Settings > General, with {path} for the worktree.")
  }

  public static func editorNotInstalled(_ name: String) -> PresentedError {
    PresentedError(
      title: "\(name) is not installed",
      message: "Install \(name), or choose another editor in Settings > General, then use Refresh."
    )
  }

  public static func themeUnreadable(_ problem: String) -> PresentedError {
    PresentedError(title: "A theme file could not be read", message: problem)
  }
}
