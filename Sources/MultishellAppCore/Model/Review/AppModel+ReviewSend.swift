import Foundation
import MultishellCore

extension AppModel {
  /// Every pending comment written to one file, mentioned in the agent's prompt,
  /// then marked sent; nothing is marked where any step fails. The pane named,
  /// never another: Send's picker showed it, and a script named it.
  @discardableResult
  public func sendReview(
    of worktreeID: Worktree.ID,
    to sessionID: TerminalSession.ID,
    takingFocus: Bool,
  ) -> Bool {
    let pending = reviewComments(in: worktreeID).filter(\.isPending)
    guard !pending.isEmpty, let worktree = workspace.worktree(worktreeID),
      let recipient = handoffRecipient(id: sessionID, in: worktreeID)
    else { return false }
    guard
      deliverHandoff(
        AgentHandoff.document(
          introduction: ReviewHandoff.introduction,
          entries: ReviewHandoff.entries(of: pending),
        ),
        named: ReviewHandoff.fileName(forWorktreeNamed: workspace.displayName(of: worktree)),
        sentence: { t("review.handoff-sentence", $0) },
        to: recipient,
        takingFocus: takingFocus,
      ) == .delivered
    else { return false }
    markReviewCommentsSent(
      Set(pending.map(\.id)),
      in: worktreeID,
      to: recipient.agentName,
      at: Date(),
    )
    reviewSendReceipts[worktreeID] = ReviewSendReceipt(
      count: pending.count,
      agentName: recipient.agentName,
    )
    return true
  }
}
