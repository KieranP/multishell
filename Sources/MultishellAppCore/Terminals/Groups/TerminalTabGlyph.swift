/// What a terminal tab's glyph shows where no agent's mark takes its place.
public enum TerminalTabGlyph: Equatable, Sendable {
  case action
  case split
  case terminal

  /// One pane's glyph, a sidebar row's, a board card's or a switcher row's: an
  /// action's, else a shell's.
  public init(paneIsAction: Bool) {
    self = paneIsAction ? .action : .terminal
  }
}
