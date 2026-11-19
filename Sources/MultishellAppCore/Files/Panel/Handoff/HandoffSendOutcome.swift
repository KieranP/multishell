import MultishellCore

/// What a PR or CI page's Send did, which `pr send` and `ci send` answer by.
public enum HandoffSendOutcome: Equatable, Sendable {
  /// Another Send from the page is still under way.
  case alreadySending
  /// The script that asked hung up before the Send went, so nothing went.
  case cancelled
  /// The checks the Send needed could not be read, in the tool's words.
  case checksNotRead(reason: String)
  /// The worktree shows no pull request, or no run, to send from.
  case noPage
  /// No pane named or picked has an agent, or it closed while the logs were read.
  case noRecipient
  /// Nothing was left checked when it would have gone.
  case nothingChecked
  /// The pane took no paste: it closed, or its shell has not started.
  case notPasted(to: TerminalSession.ID)
  /// The file could not be written; its error was presented.
  case notWritten
  case sent(itemCount: Int, to: HandoffRecipient)
  /// The threads the Send needed could not be read, in the tool's words.
  case threadsNotRead(reason: String)
}
