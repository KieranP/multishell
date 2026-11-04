import MultishellCore

/// What `ui switcher` calls a section.
extension QuickSwitcherSection.Kind {
  var commandName: String {
    switch self {
    case .waiting: "waiting"
    case .recent: "recent"
    case .places: "places"
    case .files: "files"
    case .changedFiles: "changed-files"
    case .commands: "commands"
    case .worktrees: "worktrees"
    case .tabs: "tabs"
    case .agents: "agents"
    }
  }
}
