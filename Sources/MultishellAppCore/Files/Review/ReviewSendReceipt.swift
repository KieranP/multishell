import MultishellCore

/// What Review says after a Send.
public struct ReviewSendReceipt: Equatable, Sendable {
  let count: Int
  let agentName: String

  /// "3 comments sent to Claude Code".
  public var summary: String {
    t("review.sent-summary", t("count.comments", count), agentName)
  }
}
