/// One report a program in a terminal made about itself through OSC 7501,
/// the program status protocol. See Docs/design/agents/program-status.md.
public struct ProgramStatus: Hashable, Sendable {
  /// The protocol's states; `clear` is none, the record and every record
  /// under it going.
  public enum State: Hashable, Sendable {
    case idle
    case working
    case done
    case blocked
    case failed
    case clear
  }

  public enum BlockedReason: Hashable, Sendable {
    case permission
    case question
    case auth
  }

  public let state: State
  /// What a blocked program needs, where it said; libghostty reads it only
  /// for `blocked`.
  public let blockedReason: BlockedReason?
  /// `nil` for the program's own record, else a child record such as a
  /// background task; a `/` puts one record under another.
  public let recordID: String?
  /// The program's name for itself, as `claude-code`.
  public let app: String?
  /// One line for people. Cut as a channel report's is.
  public let message: String?

  public init(
    state: State,
    blockedReason: BlockedReason? = nil,
    recordID: String? = nil,
    app: String? = nil,
    message: String? = nil,
  ) {
    self.state = state
    self.blockedReason = blockedReason
    self.recordID = recordID
    self.app = app
    self.message = SessionStateReport.truncatedMessage(message)
  }
}
