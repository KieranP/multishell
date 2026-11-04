/// What `ui switcher --scope` calls the scope bar's buttons.
extension QuickSwitcherScope: CommandNamed {
  var commandName: String {
    switch self {
    case .agents: "agents"
    case .all: "all"
    case .commands: "commands"
    case .files: "files"
    case .tabs: "tabs"
    case .worktrees: "worktrees"
    }
  }
}
