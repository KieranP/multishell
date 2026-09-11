import Foundation
import MultishellCore

/// The alerts the model raises itself, rather than from an error. In one
/// place so the wording is tested and shared by every frontend.
extension PresentedError {
  public static func notARepository(_ url: URL) -> PresentedError {
    PresentedError(
      title: t("error.not-a-repository-title"),
      message: t("error.not-a-repository-message", url.lastPathComponent))
  }

  /// A shell spawned in a missing directory silently lands in $HOME, which
  /// is worse than an honest refusal.
  public static func worktreeDirectoryMissing(_ path: String) -> PresentedError {
    PresentedError(
      title: t("error.worktree-missing-title"),
      message: t("error.worktree-missing-message", path))
  }

  public static var noAgentChosen: PresentedError {
    PresentedError(
      title: t("error.no-agent-title"), message: t("error.no-agent-message"))
  }

  /// The tab has already opened as a plain shell by the time this shows.
  public static func agentNotInstalled(_ name: String) -> PresentedError {
    PresentedError(
      title: t("error.not-installed-title", name),
      message: t("error.agent-not-installed-message", name))
  }

  public static var noEditorChosen: PresentedError {
    PresentedError(
      title: t("error.no-editor-title"), message: t("error.no-editor-message"))
  }

  public static var noEditorCommand: PresentedError {
    PresentedError(
      title: t("error.no-editor-command-title"),
      message: t("error.no-editor-command-message"))
  }

  public static func editorNotInstalled(_ name: String) -> PresentedError {
    PresentedError(
      title: t("error.not-installed-title", name),
      message: t("error.editor-not-installed-message", name))
  }

  public static func themeUnreadable(_ problem: String) -> PresentedError {
    PresentedError(title: t("error.theme-unreadable-title"), message: problem)
  }
}
