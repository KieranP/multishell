/// One step of a search in a session's scrollback, the engine keeping the
/// matches and which is selected; see Docs/design/terminals.md.
public enum TerminalSearch: Equatable, Sendable {
  /// Search for this text, replacing any search running; the engine highlights
  /// and selects nothing until a step. Empty ends the search and its highlights.
  case find(String)
  /// The match nearest the prompt, for the first step after a needle.
  case nearest
  /// The match after the selected one, down the scrollback towards the
  /// prompt, wrapping to the oldest past the newest.
  case next
  /// The match before it, up the scrollback, wrapping the other way.
  case previous
  /// The bar has closed: the search is over and its highlights come down.
  case end
}
