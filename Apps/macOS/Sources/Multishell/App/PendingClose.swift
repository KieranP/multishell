import MultishellCore

/// A close waiting on the confirmation dialog, because the pane or tab has
/// an agent that reported Working. Cmd+W on a working agent is a mistake
/// often enough to ask, the way worktree removal does.
enum PendingClose: Identifiable, Equatable {
  case pane(TerminalSession.ID)
  case tab(TerminalTab.ID)

  var id: String {
    switch self {
    case .pane(let id): "pane-\(id.uuidString)"
    case .tab(let id): "tab-\(id.uuidString)"
    }
  }

  var title: String {
    switch self {
    case .pane: "Close this pane?"
    case .tab: "Close this tab?"
    }
  }

  var buttonLabel: String {
    switch self {
    case .pane: "Close Pane"
    case .tab: "Close Tab"
    }
  }
}
