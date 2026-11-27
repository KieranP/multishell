/// What a terminal tab's glyph shows where no agent's mark takes its place.
public enum TerminalTabGlyph: Equatable, Sendable {
  case action
  case split
  case terminal

  /// One pane's glyph, a sidebar row's or a board card's: an action's, else a
  /// shell's.
  public init(paneIsAction: Bool) {
    self = paneIsAction ? .action : .terminal
  }
}
