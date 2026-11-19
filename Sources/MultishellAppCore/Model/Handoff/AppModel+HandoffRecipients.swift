import Foundation
import MultishellCore

extension AppModel {
  /// How many panes a worktree's focus history keeps: the picker needs only the
  /// newest agent among them.
  private static var focusHistoryLength: Int { 16 }

  /// The worktree's live panes with an agent, working or not, in the board's order.
  func handoffRecipients(in worktreeID: Worktree.ID) -> [HandoffRecipient] {
    agentBoard.columns.flatMap(\.cards)
      .filter { $0.worktreeID == worktreeID }
      .compactMap(HandoffRecipient.init(card:))
  }

  /// The pane `id`, while it is the worktree's and has an agent.
  func handoffRecipient(id: TerminalSession.ID, in worktreeID: Worktree.ID) -> HandoffRecipient? {
    handoffRecipients(in: worktreeID).first { $0.id == id }
  }

  /// The pane named, else the one the worktree's picker shows.
  func handoffRecipient(
    named id: TerminalSession.ID?,
    in worktreeID: Worktree.ID,
  ) -> HandoffRecipient? {
    id.map { handoffRecipient(id: $0, in: worktreeID) } ?? handoffRecipient(in: worktreeID)
  }

  /// As `handoffRecipient(named:in:)`, a pane named and gone said over `page`'s foot:
  /// it closed after the picker drew.
  func handoffRecipientNotingMiss(
    named id: TerminalSession.ID?,
    on page: ServicePage,
    in worktreeID: Worktree.ID,
  ) -> HandoffRecipient? {
    let recipient = handoffRecipient(named: id, in: worktreeID)
    // A pane still open but with no agent, a script's `--to` a shell, closed nothing.
    if recipient == nil, let id, workspace.session(id) == nil {
      noteHandoffMiss(t("handoff.pane-gone"), on: page, in: worktreeID)
    }
    return recipient
  }

  /// The one picked, else the agent focused last in the worktree, else the first.
  func handoffRecipient(in worktreeID: Worktree.ID) -> HandoffRecipient? {
    handoffRecipient(from: handoffRecipients(in: worktreeID), in: worktreeID)
  }

  func handoffRecipient(
    from recipients: [HandoffRecipient],
    in worktreeID: Worktree.ID,
  ) -> HandoffRecipient? {
    let preferred = [handoff.recipientPicks[worktreeID]] + (focusedSessionHistory[worktreeID] ?? [])
    for case let id? in preferred {
      if let recipient = recipients.first(where: { $0.id == id }) { return recipient }
    }
    return recipients.first
  }

  public func pickHandoffRecipient(_ id: TerminalSession.ID, in worktreeID: Worktree.ID) {
    setIfChanged(\.handoff.recipientPicks[worktreeID], id)
    setIfChanged(\.handoff.misses[worktreeID], nil)
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
}
