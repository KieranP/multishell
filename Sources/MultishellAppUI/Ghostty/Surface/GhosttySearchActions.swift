import MultishellCore

/// The keybind actions the find bar sends libghostty, the only form it takes a
/// search step in. A find is its text alone: a step sent with it ran before any match.
enum GhosttySearchActions {
  /// Ghostty's keybind spelling of each step. Its `next` walks newest to oldest,
  /// up the scrollback, so the directions cross; from nothing it is the newest.
  static func action(for command: TerminalSearch) -> String {
    switch command {
    case .find(let text): "search:\(text)"
    case .nearest: "navigate_search:next"
    case .next: "navigate_search:previous"
    case .previous: "navigate_search:next"
    case .end: "end_search"
    }
  }
}
