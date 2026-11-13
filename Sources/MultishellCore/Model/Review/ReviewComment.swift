import Foundation

/// A note on lines of a file tab, collected per worktree until sent to an
/// agent; see Docs/design/files/review-comments.md.
public struct ReviewComment: Identifiable, Codable, Hashable, Sendable {
  public enum State: Codable, Hashable, Sendable {
    case pending
    case sent(agentName: String, at: Date)
    /// Sent, and the agent has since changed the lines it is on.
    case outdated(agentName: String, at: Date)
  }

  public let id: UUID
  /// Relative to the worktree, as a file tab keys its file.
  public let path: String
  /// Never mixed: a range starting on removed lines stays on the committed side.
  public let side: DiffSide
  /// What the committed side was when written, its text differing between scopes.
  public let scope: ChangeScope
  /// Numbered on `side`, moved as the lines move.
  public internal(set) var lines: ClosedRange<Int>
  /// The lines' text when written, which re-anchoring searches for.
  public let quote: [String]
  public internal(set) var text: String
  public internal(set) var state: State
  /// Its lines no longer read as `quote`; a sent comment's did not when sent.
  public internal(set) var hasChangedLines: Bool

  public var isPending: Bool { state == .pending }

  /// When it was sent, `nil` while pending.
  private var sentAt: Date? {
    switch state {
    case .pending: nil
    case .sent(_, let at), .outdated(_, let at): at
    }
  }

  public init(
    path: String,
    side: DiffSide,
    scope: ChangeScope,
    lines: ClosedRange<Int>,
    quote: [String],
    text: String,
  ) {
    self.id = UUID()
    self.path = path
    self.side = side
    self.scope = scope
    self.lines = lines
    self.quote = quote
    self.text = text
    self.state = .pending
    self.hasChangedLines = false
  }

  /// Only while pending: a sent comment is what the agent read.
  public mutating func edit(text: String) {
    guard isPending else { return }
    self.text = text
  }

  public mutating func markSent(to agentName: String, at date: Date) {
    guard isPending else { return }
    state = .sent(agentName: agentName, at: date)
  }

  /// Its quote found at `lines`: its lines read as written again, and an outdated
  /// one reads as the agent was sent it.
  public mutating func anchor(at lines: ClosedRange<Int>) {
    self.lines = lines
    hasChangedLines = false
    if case .outdated(let agentName, let at) = state {
      state = .sent(agentName: agentName, at: at)
    }
  }

  /// Its quote found nowhere. Its lines stay as they were for the next read to
  /// search near. One sent with its lines already changed stays sent.
  public mutating func noteLinesChanged() {
    switch state {
    case .pending:
      hasChangedLines = true

    case .sent(let agentName, let at):
      if !hasChangedLines { state = .outdated(agentName: agentName, at: at) }

    case .outdated:
      break
    }
  }

  /// Sent long enough ago that the drops sweep has removed the file it went in.
  public func outlivesItsSentFile(at now: Date, retention: TimeInterval) -> Bool {
    guard let sentAt else { return false }
    return now.timeIntervalSince(sentAt) > retention
  }

  /// Its lines are in what `scope` reads: the file on disk always, the committed
  /// side only under the scope it was written in.
  public func appliesUnder(_ scope: ChangeScope) -> Bool {
    side.isRead(under: scope, writtenUnder: self.scope)
  }
}
