import MultishellCore

/// An action picked while something still runs in its tab: restarting ends it.
public struct PendingActionRestart: Identifiable, Equatable, Sendable {
  /// The tab and the name asked about: a rename asks again, and the sheet up
  /// is replaced by one with the new name.
  public struct AskedAbout: Hashable, Sendable {
    let sessionID: TerminalSession.ID
    let actionName: String
  }

  let worktreeID: Worktree.ID
  let sessionID: TerminalSession.ID
  let actionName: String

  public var id: AskedAbout { AskedAbout(sessionID: sessionID, actionName: actionName) }

  public var title: String { t("project-action.restart-title", actionName) }
  public var message: String { t("project-action.restart-message") }
  public var confirmLabel: String { t("project-action.restart-button") }
}
