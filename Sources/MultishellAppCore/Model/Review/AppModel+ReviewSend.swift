import Foundation
import MultishellCore

extension AppModel {
  /// How many panes a worktree's focus history keeps: the picker needs only the
  /// newest agent among them.
  private static var focusHistoryLength: Int { 16 }

  /// The worktree's live panes with an agent, working or not, in the board's order.
  func reviewRecipients(in worktreeID: Worktree.ID) -> [ReviewRecipient] {
    agentBoard.columns.flatMap(\.cards)
      .filter { $0.worktreeID == worktreeID }
      .compactMap(ReviewRecipient.init(card:))
  }

  /// The one picked, else the agent focused last in the worktree, else the first.
  func reviewRecipient(in worktreeID: Worktree.ID) -> ReviewRecipient? {
    reviewRecipient(from: reviewRecipients(in: worktreeID), in: worktreeID)
  }

  func reviewRecipient(
    from recipients: [ReviewRecipient],
    in worktreeID: Worktree.ID,
  ) -> ReviewRecipient? {
    let preferred = [reviewRecipientPicks[worktreeID]] + (focusedSessionHistory[worktreeID] ?? [])
    for case let id? in preferred {
      if let recipient = recipients.first(where: { $0.id == id }) { return recipient }
    }
    return recipients.first
  }

  public func pickReviewRecipient(_ id: TerminalSession.ID, in worktreeID: Worktree.ID) {
    setIfChanged(\.reviewRecipientPicks[worktreeID], id)
  }

  /// What the reconciler reports as a pane takes focus.
  func noteSessionFocused(_ id: TerminalSession.ID) {
    guard let worktreeID = workspace.session(id)?.worktreeID else { return }
    var history = focusedSessionHistory[worktreeID] ?? []
    history.removeAll { $0 == id }
    history.insert(id, at: 0)
    setIfChanged(
      \.focusedSessionHistory[worktreeID],
      Array(history.prefix(Self.focusHistoryLength)),
    )
  }

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
      let recipient = reviewRecipients(in: worktreeID).first(where: { $0.id == sessionID })
    else { return false }
    let mentionPrefix = fileMentionPrefix(ofAgent: recipient.agentID)
    let file: URL
    do {
      file = try AgentHandoff.write(
        AgentHandoff.document(
          introduction: ReviewHandoff.introduction,
          entries: ReviewHandoff.entries(of: pending),
        ),
        named: ReviewHandoff.fileName(forWorktreeNamed: workspace.displayName(of: worktree)),
        in: dropsDirectory,
      )
    } catch {
      present(error)
      return false
    }
    guard let mention = handoffMention(of: file, prefixed: mentionPrefix),
      host.paste(mention + " ", into: sessionID)
    else {
      DropCopies.remove(file.deletingLastPathComponent())
      return false
    }
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
    if takingFocus {
      store.focusSession(sessionID)
      reconcileSessions(takingFocus: true)
    }
    return true
  }

  /// A mention where the agent reads them, else a sentence around the path, which
  /// alone says nothing. Absolute: the drops directory is outside every worktree.
  private func handoffMention(of file: URL, prefixed prefix: String?) -> String? {
    guard let text = FilePathText.pastedText(for: [file], relativeTo: nil, mentionPrefix: prefix)
    else { return nil }
    return prefix == nil ? t("review.handoff-sentence", text) : text
  }
}
