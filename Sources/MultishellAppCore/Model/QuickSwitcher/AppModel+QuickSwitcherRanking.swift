import MultishellCore

/// The order the quick switcher's rows come in: by how well the text names
/// them, a waiting agent lifted, or by how long an agent has been in its state.
extension AppModel {
  /// Enough to lift a question over a slightly better-matching name, not over
  /// a row the text names far better.
  private static var waitingBonus: Int { 120 }

  /// Waiting longest first, the one owed an answer longest; any other state
  /// newest first, as its column on the board.
  static func quickSwitcherBySince(
    _ items: [QuickSwitcherItem],
    in lane: AgentBoardLane,
  )
    -> [QuickSwitcherItem]
  {
    items.enumerated().sorted { lhs, rhs in
      DateOrder.precedes(lhs.element.since, rhs.element.since, newestFirst: lane != .waiting)
        ?? (lhs.offset < rhs.offset)
    }.map(\.element)
  }

  /// Failed waits with Waiting, as on the board. A worktree holding a waiting
  /// agent is not lifted with it, the agent being what asked.
  static func isQuickSwitcherWaitingAgent(_ item: QuickSwitcherItem) -> Bool {
    item.kind.isAgent && AgentBoardLane.of(item.state) == .waiting
  }

  /// Between two equal matches, the more particular place first; it breaks a
  /// tie and is never added to a score.
  private static func kindBias(_ kind: QuickSwitcherItem.Kind) -> Int {
    switch kind {
    case .agent: 40
    case .worktree: 30
    case .project: 20
    case .shell, .fileTab: 10
    case .file, .command: 0
    }
  }

  /// Best match first, a waiting agent lifted; `QuickSwitcherRankedRow` breaks
  /// a tie.
  func quickSwitcherRanked(
    _ items: [QuickSwitcherItem],
    by query: QuickSwitcherQuery,
  ) -> [QuickSwitcherItem] {
    guard !query.isEmpty else { return items }
    let matched = items.enumerated().compactMap { offset, item -> QuickSwitcherRankedRow? in
      guard let match = QuickSwitcherMatch(query, title: item.title, location: item.location) else {
        return nil
      }
      var shown = item
      shown.titleOffsets = match.titleOffsets
      let lift = Self.isQuickSwitcherWaitingAgent(item) ? Self.waitingBonus : 0
      return QuickSwitcherRankedRow(
        score: match.score + lift,
        titleLength: item.title.count,
        kindBias: Self.kindBias(item.kind),
        offset: offset,
        item: shown,
      )
    }
    return matched.sorted { $0.precedes($1) }.map(\.item)
  }
}
