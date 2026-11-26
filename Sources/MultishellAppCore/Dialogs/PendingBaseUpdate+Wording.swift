import MultishellCore
import MultishellGitKit

extension PendingBaseUpdate {
  /// "Rebase fix/rate-limit onto origin/main?"
  public var title: String {
    switch method {
    case .merge: t("base-update.merge-title", worktree.name, base.shortName)
    case .rebase: t("base-update.rebase-title", worktree.name, base.shortName)
    }
  }

  /// Each reason that applies, a paragraph of its own.
  public var message: String {
    var paragraphs: [String] = []
    if rewritesPushedBranch { paragraphs.append(t("base-update.pushed-message")) }
    if let workingAgentName {
      paragraphs.append(t("base-update.agent-working-message", workingAgentName, method.noun))
    }
    return paragraphs.joined(separator: "\n\n")
  }

  public var confirmLabel: String { method.actionLabel }
}
