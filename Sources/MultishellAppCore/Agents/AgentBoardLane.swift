import MultishellCore

/// A column of the board, and the rule that puts a pane in one.
///
/// Left to right, most urgent first. Failed goes with Waiting rather than
/// with Done: a failure wants the user, which is what that column means, and
/// it leaves Done meaning one thing so its name can say so.
public enum AgentBoardLane: String, CaseIterable, Sendable {
  case waiting
  case working
  case done
  case idle

  public var title: String {
    switch self {
    case .waiting: "Waiting for you"
    case .working: "Working"
    case .done: "Done"
    case .idle: "Idle"
    }
  }

  /// The state whose colour the column header wears. Waiting wears the
  /// question's blue though it also holds failures: the column is named for
  /// what it asks of the user, not for how a card came to be in it.
  public var headerState: SessionState {
    switch self {
    case .waiting: .attention
    case .working: .running
    case .done: .done
    case .idle: .idle
    }
  }

  /// The lanes the sidebar entry carries a count for. Idle is left off: it
  /// is where most cards rest, so its number says nothing about whether the
  /// board is worth opening.
  public static let summarised: [AgentBoardLane] = [.waiting, .working, .done]

  public static func of(_ state: SessionState?) -> AgentBoardLane {
    switch state {
    case .attention, .error: .waiting
    case .running: .working
    case .done: .done
    case .idle, nil: .idle
    }
  }
}
