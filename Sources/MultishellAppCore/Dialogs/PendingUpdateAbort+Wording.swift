import MultishellCore

extension PendingUpdateAbort {
  /// "Abort the rebase of fix/rate-limit?"
  public var title: String { t("base-update.abort-title", method.noun, worktreeName) }

  public var message: String { t("base-update.abort-agent-working-message", workingAgentName) }

  public var confirmLabel: String { method.abortLabel }
}
