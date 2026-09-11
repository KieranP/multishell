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

  /// Said under the columns whenever there is nothing on them. Not gated on
  /// whether any hooks are installed: one agent's being in place says
  /// nothing about the agent actually at the prompt, and a user with Codex
  /// set up and Claude Code running would get the empty board with no word
  /// of why. The columns themselves are always drawn, so this is a line
  /// rather than a page.
  ///
  /// It names no agent and offers to install none: the settings tab lists
  /// whatever detection found on the PATH, and pointing at it is as far as
  /// anything here goes.
  public static var emptyHint: String { t("board.empty-hint") }
}
