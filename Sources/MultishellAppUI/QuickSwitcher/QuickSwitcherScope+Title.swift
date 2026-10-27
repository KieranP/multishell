import MultishellAppCore

extension QuickSwitcherScope {
  var title: String {
    switch self {
    case .all: t("quick-switcher.scope.all")
    case .agents: t("quick-switcher.scope.agents")
    case .worktrees: t("quick-switcher.scope.worktrees")
    case .tabs: t("quick-switcher.scope.tabs")
    case .files: t("quick-switcher.scope.files")
    case .commands: t("quick-switcher.scope.commands")
    }
  }

  /// What the empty field asks for in this scope.
  var prompt: String {
    switch self {
    case .all: t("quick-switcher.prompt.all")
    case .agents: t("quick-switcher.prompt.agents")
    case .worktrees: t("quick-switcher.prompt.worktrees")
    case .tabs: t("quick-switcher.prompt.tabs")
    case .files: t("quick-switcher.prompt.files")
    case .commands: t("quick-switcher.prompt.commands")
    }
  }
}
