import MultishellCore

/// A close waiting on the confirmation dialog, because the pane or tab has
/// an agent that reported Working. Cmd+W on a working agent is a mistake
/// often enough to ask, the way worktree removal does.
public enum PendingClose: Identifiable, Equatable, Sendable {
  case pane(TerminalSession.ID)
  case tab(TerminalTab.ID)

  public var id: String {
    switch self {
    case .pane(let id): "pane-\(id.uuidString)"
    case .tab(let id): "tab-\(id.uuidString)"
    }
  }

  public var title: String {
    switch self {
    case .pane: "Close this pane?"
    case .tab: "Close this tab?"
    }
  }

  public var buttonLabel: String {
    switch self {
    case .pane: "Close Pane"
    case .tab: "Close Tab"
    }
  }

  /// The shells this close would end: the one pane, or every pane of the
  /// tab. What decides whether the question is asked at all.
  public func sessionIDs(in tab: TerminalTab) -> [TerminalSession.ID] {
    switch self {
    case .pane(let id): [id]
    case .tab: tab.sessionIDs
    }
  }
}
