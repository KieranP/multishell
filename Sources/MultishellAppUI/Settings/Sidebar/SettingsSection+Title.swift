import MultishellAppCore

extension SettingsSection {
  /// The sidebar row of a part of a split page; `nil` for a whole page.
  var partTitle: String? {
    switch self {
    case .agentHooks: t("settings.agent-hooks")
    case .agentSettings: t("settings.agent-settings")
    case .hooksCreate: t("hooks.create")
    case .hooksDelete: t("hooks.delete")
    case .hooksEnvironment: t("hooks.environment")
    case .agents, .appearance, .general, .integrations, .notifications, .terminal, .worktrees: nil
    }
  }

  /// The window's title: the page, and the part where the page is split.
  var title: String {
    partTitle.map { t("settings.part-title", page.title, $0) } ?? page.title
  }
}
