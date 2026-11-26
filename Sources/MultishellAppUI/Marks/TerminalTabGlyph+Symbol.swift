import MultishellAppCore

extension TerminalTabGlyph {
  var symbol: String {
    switch self {
    case .action: PaneSymbol.action
    case .split: PaneSymbol.split
    case .terminal: PaneSymbol.terminal
    }
  }
}
