/// What the engine's search found, as it reports each half apart: `nil` where
/// it does not know yet, the search has ended, or no match is selected.
public enum TerminalSearchCount: Equatable, Sendable {
  case selected(Int?)
  case total(Int?)
}
