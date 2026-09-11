import MultishellCore

/// What the board and the sidebar entry say about themselves, kept out of
/// the views so the wording is tested rather than read off a screenshot.
extension AgentBoard {
  /// Beside the title: how many terminals are on the board, and how many of
  /// them want the user.
  public var summary: String {
    let terminals = t("count.terminals", cardCount)
    let waiting = count(of: .waiting)
    return waiting > 0
      ? t("board.summary", terminals, t("count.waiting-on-you", waiting)) : terminals
  }

  /// Said under the columns whenever there is nothing on them, and not gated
  /// on hooks being installed; see docs/design/agents.md.
  public static var emptyHint: String { t("board.empty-hint") }
}
