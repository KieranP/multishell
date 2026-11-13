import MultishellCore

/// The state a comment's row and card show beside its lines.
public enum ReviewChip: Equatable, Sendable {
  /// Pending, its lines no longer reading as written.
  case linesChanged
  case outdated
  case sent(agentName: String)
  case toSend

  /// How the chip is tinted: stale lines outrank waiting to be sent.
  public enum Tone: Sendable {
    case sent
    case stale
    case toSend
  }

  public var title: String {
    switch self {
    case .toSend: t("review.chip-to-send")
    case .linesChanged: t("review.chip-lines-changed")
    case .sent(let agentName): t("review.chip-sent", agentName)
    case .outdated: t("review.chip-outdated")
    }
  }

  /// Delete for a comment not yet sent, Dismiss for one the agent has read.
  public var removeTitle: String {
    switch self {
    case .toSend, .linesChanged: t("review.delete")
    case .sent, .outdated: t("review.dismiss")
    }
  }

  /// Lines that no longer read as the comment saw them show what it saw.
  public var showsQuote: Bool { tone == .stale }

  public var tone: Tone {
    switch self {
    case .linesChanged, .outdated: .stale
    case .toSend: .toSend
    case .sent: .sent
    }
  }

  public init(_ comment: ReviewComment) {
    switch comment.state {
    case .pending: self = comment.hasChangedLines ? .linesChanged : .toSend
    case .sent(let agentName, _): self = .sent(agentName: agentName)
    case .outdated: self = .outdated
    }
  }
}
