import MultishellCore

/// What the board says about itself, kept out of the views so the wording
/// is tested rather than read off a screenshot.
extension AgentBoard {
  /// Said under the columns whenever there is nothing on them, and not gated
  /// on hooks being installed; see Docs/design/agents.md.
  public static var emptyHint: String { t("board.empty-hint") }

  /// Beside the title: how many terminals are on the board, and how many of
  /// them want the user.
  public var summary: String {
    let terminals = t("count.terminals", cardCount)
    let waiting = count(of: .waiting)
    return waiting > 0
      ? t("board.summary", terminals, t("count.waiting-on-you", waiting)) : terminals
  }
}
