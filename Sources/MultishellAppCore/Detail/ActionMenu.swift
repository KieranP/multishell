/// What a worktree's play button offers: the actions in force, and those of
/// a `.multishell.json` not yet trusted, listed to be trusted, not run.
public struct ActionMenu: Equatable, Sendable {
  /// The user's own, then the file's, each left out when empty: a divider
  /// goes between them.
  public let groups: [[ActionMenuItem]]
  public let awaitingTrust: [String]

  public var items: [ActionMenuItem] { groups.flatMap(\.self) }

  /// Rows carry a state mark only while one has a state: blank marks alone
  /// indented every name for nothing.
  public var marksRows: Bool { items.contains { $0.markedState != nil } }

  public var offersReviewAndTrust: Bool { !awaitingTrust.isEmpty }

  /// A divider over Edit Actions… only where rows sit above it.
  public var separatesEditItems: Bool { !groups.isEmpty || !awaitingTrust.isEmpty }

  /// A dot on the button while any action here runs.
  public var isAnyRunning: Bool { items.contains(where: \.state.isRunning) }

  /// Held still under Reduce Motion, as `StateDot` is everywhere else.
  public func turnsWorkingDots(reducingMotion: Bool) -> Bool {
    isAnyRunning && !reducingMotion
  }
}
