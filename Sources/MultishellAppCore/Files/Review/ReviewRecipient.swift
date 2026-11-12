import Foundation
import MultishellCore

/// An agent pane a review can be sent to, as Review's picker lists it.
public struct ReviewRecipient: Identifiable, Equatable, Sendable {
  public let id: TerminalSession.ID
  public let agentID: String
  public let agentName: String
  public let tabTitle: String
  private let lane: AgentBoardLane
  private let since: Date?

  /// A shell's card has no agent to send to.
  init?(card: AgentBoardCard) {
    guard case .agent(let agentID, let agentName) = card.occupant else { return nil }
    self.id = card.id
    self.agentID = agentID
    self.agentName = agentName
    self.tabTitle = card.title
    self.lane = card.lane
    self.since = card.since
  }

  /// "at its prompt", "working for 6m", in the board's words for its state.
  public func stateText(at now: Date) -> String {
    switch lane {
    case .working:
      ElapsedText.short(since: since, now: now).map { t("review.recipient-working-for", $0) }
        ?? lane.title(inSentence: true)

    case .waiting: lane.title(inSentence: true)
    case .done, .idle: t("review.recipient-at-prompt")
    }
  }
}
