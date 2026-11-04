/// What `ui switcher` calls a row's kind.
extension QuickSwitcherItem.Kind {
  var commandName: String {
    switch self {
    case .agent: "agent"
    case .command: "command"
    case .file: "file"
    case .fileTab: "file-tab"
    case .project: "project"
    case .shell: "shell"
    case .worktree: "worktree"
    }
  }
}
