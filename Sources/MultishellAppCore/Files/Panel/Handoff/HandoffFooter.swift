/// A Send foot on Review, the PR or the CI page: what the last Send did until
/// there is more to send, else the picker and Send, else why nobody can be sent to.
public enum HandoffFooter: Equatable, Sendable {
  case noRecipient(String)
  /// "Reading 2 logs": Send is off until they are read and sent.
  case reading(String)
  case ready(picked: HandoffRecipient, recipients: [HandoffRecipient], canSend: Bool)
  /// "3 comments sent to Claude Code".
  case sent(summary: String)
}
