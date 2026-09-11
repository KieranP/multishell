import MultishellCore

/// A column of the board, most urgent first. Failed goes with Waiting; see
/// docs/design/agents.md.
public enum AgentBoardLane: String, CaseIterable, Sendable {
  case waiting
  case working
  case done
  case idle

  /// `inSentence` is the same name mid-sentence, for the screen reader; see
  /// docs/design/translation.md.
  public func title(inSentence: Bool = false) -> String {
    switch self {
    case .waiting: inSentence ? t("lane.waiting-in-sentence") : t("lane.waiting")
    case .working: inSentence ? t("lane.working-in-sentence") : t("lane.working")
    case .done: inSentence ? t("lane.done-in-sentence") : t("lane.done")
    case .idle: inSentence ? t("lane.idle-in-sentence") : t("lane.idle")
    }
  }

  /// The state whose colour the column header wears. Waiting wears blue
  /// though it holds failures, being named for what it asks.
  public var headerState: SessionState {
    switch self {
    case .waiting: .attention
    case .working: .running
    case .done: .done
    case .idle: .idle
    }
  }

  /// The lanes the sidebar entry counts. Idle is left off, being where most
  /// cards rest.
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
