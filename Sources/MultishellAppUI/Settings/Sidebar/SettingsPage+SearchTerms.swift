import MultishellAppCore
import MultishellCore
import MultishellGitKit

extension SettingsPage {
  private var allProjectsRowLabels: [String] {
    switch self {
    case .agents:
      [
        t("agents.section-preferred"), t("agents.preferred-agent"), t("label.command"),
        t("agents.flags"),
        t("agents.auto-start-tab"), t("agents.auto-start-create"), t("agents.auto-rename"),
        t("agents.rename-agent"), t("agents.rename-model"), t("agents.rename-effort"),
        t("agents.hooks-section"), t("agents.command-line-tool"), t("agents.helper-label"),
        t("agents.install-helper"),
      ]

    case .appearance:
      [
        t("appearance.section-theme"), t("appearance.theme"), t("appearance.theme-files"),
        t("appearance.section-terminal"), t("appearance.terminal-font"),
        t("appearance.terminal-size"), t("appearance.section-file-tabs"),
        t("appearance.file-font"), t("appearance.file-size"),
        t("appearance.section-interface"), t("appearance.ui-font"), t("appearance.ui-size"),
      ]

    case .general:
      [
        t("general.section-editor"), t("general.editor"), t("label.command"),
        t("general.section-files-panel"), t("general.show-hidden-files"),
        t("general.section-storage"), t("general.state-file"),
      ]

    case .notifications:
      [t("notifications.header")] + NotificationSettingsText.rows.map(\.title)

    case .terminal:
      [
        t("terminal.section-new-tabs"), t("terminal.default-shell"), t("terminal.path"),
        t("terminal.section-first-terminal"), t("terminal.open-on-select"),
        t("terminal.open-on-create"),
      ]

    case .worktrees:
      [
        t("worktrees.section-creating"), t("worktrees.path"), t("worktrees.branch-prefix"),
        t("worktrees.hook-timeout"), t("worktrees.section-ports"),
        t("worktrees.port-block-start"), t("worktrees.port-block-size"),
        t("worktrees.section-change-counts"), t("worktrees.indicator"),
        t("worktrees.diff-algorithm"), t("worktrees.section-removing"),
        t("worktrees.confirm-removal"), t("worktrees.delete-branch"),
        t("worktrees.trash-removed"),
      ]

    case .hooks, .integrations: []
    }
  }

  private var projectRowLabels: [String] {
    switch self {
    case .agents:
      [
        t("project.preferred-agent"), t("project.flags"), t("agents.auto-start-tab"),
        t("agents.auto-start-create"),
      ]

    case .general:
      [
        t("project.repository"), t("project.worktrees-label"), t("project.sort-worktrees"),
        t("project.active-first"), t("project.icon"), t("project.tint-label"),
        t("action.export"), t("action.remove-project"),
      ]

    case .hooks:
      [
        t("hooks.pre-create"), t("hooks.linked-paths"), t("hooks.copied-paths"),
        t("hooks.post-create"), t("hooks.pre-delete"), t("hooks.post-delete"),
      ] + HookVariable.allCases.map(\.name)

    case .integrations:
      ServiceIntegration.settingsPageOrder.map(\.settingsLabel)

    case .terminal:
      [
        t("project.default-shell"), t("project.open-on-select-short"),
        t("project.open-on-create-short"),
      ]

    case .worktrees:
      [
        t("project.table-new-worktrees"), t("project.worktree-path"), t("project.branch-prefix"),
        t("project.default-branch"),
      ]

    case .appearance, .notifications: []
    }
  }

  /// What the sidebar's search looks through: the page's title, its parts'
  /// titles and the labels of its rows. A row added to a page belongs here too.
  func searchTerms(in scope: SettingsScope) -> [String] {
    let partTitles = sections(in: scope).compactMap(\.partTitle)
    let rows = scope == .allProjects ? allProjectsRowLabels : projectRowLabels
    return [title] + partTitles + rows
  }
}
