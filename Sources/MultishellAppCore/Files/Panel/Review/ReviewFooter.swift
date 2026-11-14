/// What Review's foot shows: what the last Send did until there is more to
/// send, else the picker and Send, else why there is nobody to send to.
public enum ReviewFooter: Equatable, Sendable {
  case noRecipient(String)
  case ready(picked: ReviewRecipient, recipients: [ReviewRecipient], canSend: Bool)
  case sent(ReviewSendReceipt)
}
