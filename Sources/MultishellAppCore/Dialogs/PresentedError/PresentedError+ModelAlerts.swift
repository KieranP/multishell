import Foundation
import MultishellCore

/// The alerts the model raises itself, rather than from an error. In one
/// place so the wording is tested and shared by every frontend.
extension PresentedError {
  static var noAgentChosen: PresentedError {
    PresentedError(
      title: t("error.no-agent-title"),
      message: t("error.no-agent-message"),
    )
  }

  static var noEditorChosen: PresentedError {
    PresentedError(
      title: t("error.no-editor-title"),
      message: t("error.no-editor-message"),
    )
  }

  static var noEditorCommand: PresentedError {
    PresentedError(
      title: t("error.no-editor-command-title"),
      message: t("error.no-editor-command-message"),
    )
  }

  static func notARepository(_ url: URL) -> PresentedError {
    PresentedError(
      title: t("error.not-a-repository-title"),
      message: t("error.not-a-repository-message", url.lastPathComponent),
    )
  }

  /// A shell spawned in a missing directory silently lands in $HOME, which
  /// is worse than an honest refusal.
  static func worktreeDirectoryMissing(_ path: String) -> PresentedError {
    PresentedError(
      title: t("error.worktree-missing-title"),
      message: t("error.worktree-missing-message", path),
    )
  }

  /// Merge from Base or Rebase onto Base over a stop the row had not read yet.
  static func unfinishedUpdate(_ method: UpdateMethod, on branch: String) -> PresentedError {
    PresentedError(
      title: t("base-update.unfinished-title", branch, method.noun),
      message: t("base-update.unfinished-message", method.continueCommand),
    )
  }

  /// Merge from Base or Rebase onto Base over a cherry-pick, revert or `git am` stopped partway.
  static func pickingCommits(on branch: String) -> PresentedError {
    PresentedError(
      title: t("base-update.picking-title", branch),
      message: t("base-update.picking-message"),
    )
  }

  /// An Abort confirmed after the stop it asked about ended and another began.
  static func abortSkipped(on branch: String) -> PresentedError {
    PresentedError(
      title: t("base-update.abort-skipped-title", branch),
      message: t("base-update.abort-skipped-message"),
    )
  }

  /// An update whose worktree switched branch while it was checked, asked or fetched.
  static func branchMoved(from branch: String, to current: String) -> PresentedError {
    PresentedError(
      title: t("base-update.branch-moved-title", branch),
      message: t("base-update.branch-moved-message", current),
    )
  }

  /// An update whose project's base changed while it was checked, asked or fetched.
  static func baseChanged(of branch: String, to base: String?) -> PresentedError {
    PresentedError(
      title: t("base-update.base-changed-title", branch),
      message: base.map { t("base-update.base-changed-message", $0) }
        ?? t("base-update.base-gone-message"),
    )
  }

  /// Send Conflicts To whose pane took no paste: it closed, or its shell has not started.
  static func conflictsNotPasted(to agentName: String) -> PresentedError {
    PresentedError(
      title: t("conflicts.not-sent-title"),
      message: t("handoff.not-pasted", agentName),
    )
  }

  static func worktreeDirectoryUnanswered(_ path: String) -> PresentedError {
    PresentedError(
      title: t("error.worktree-unanswered-title"),
      message: t("error.worktree-unanswered-message", path),
    )
  }

  /// The tab has already opened as a plain shell by the time this shows.
  static func agentNotInstalled(_ name: String) -> PresentedError {
    PresentedError(
      title: t("error.not-installed-title", name),
      message: t("error.agent-not-installed-message", name),
    )
  }

  static func editorNotInstalled(_ name: String) -> PresentedError {
    PresentedError(
      title: t("error.not-installed-title", name),
      message: t("error.editor-not-installed-message", name),
    )
  }

  static func removalStillRunning(_ path: String) -> PresentedError {
    PresentedError(
      title: t("error.removal-still-running-title"),
      message: t("error.removal-still-running-message", path),
    )
  }

  static func noPortBlock(_ worktreeName: String) -> PresentedError {
    PresentedError(
      title: t("error.no-port-block-title"),
      message: t("error.no-port-block-message", worktreeName, PortBlock.highestPort),
    )
  }

  static func themeUnreadable(_ problem: String) -> PresentedError {
    PresentedError(title: t("error.theme-unreadable-title"), message: problem)
  }
}
