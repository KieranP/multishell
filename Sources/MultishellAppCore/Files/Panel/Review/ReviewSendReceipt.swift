import MultishellCore

/// What Review says after a Send.
struct ReviewSendReceipt: Equatable, Sendable {
  let count: Int
  let agentName: String

  /// "3 comments sent to Claude Code".
  var summary: String {
    t("handoff.sent-summary", t("count.comments", count), agentName)
  }
}
