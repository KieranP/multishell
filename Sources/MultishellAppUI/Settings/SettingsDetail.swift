import MultishellAppCore
import MultishellCore
import SwiftUI

/// The settings window's page for where the sidebar points, titled with the
/// page and whose settings it shows.
struct SettingsDetail: View {
  let model: AppModel
  let location: SettingsLocation

  var body: some View {
    VStack(spacing: 0) {
      SettingsPageHeader(
        title: location.section.page.title,
        part: location.section.partTitle,
        caption: model.settingsHeaderCaption,
      )
      page
        // A fresh page per place, so a page reused for another project or
        // part starts scrolled to the top.
        .id(location)
    }
    .navigationTitle(location.section.title)
    .navigationSubtitle(model.settingsScopeName)
  }

  @ViewBuilder private var page: some View {
    switch location.scope {
    case .allProjects:
      allProjectsPage

    case .project(let id):
      if let project = model.workspace.project(id) {
        projectPage(project)
      }
    }
  }

  @ViewBuilder private var allProjectsPage: some View {
    switch location.section {
    case .agentHooks: AppAgentHooksPage(model: model)
    case .agentSettings: AppAgentSettingsPage(model: model)
    case .appearance: AppAppearancePage(model: model)
    case .general: AppGeneralPage(model: model)
    case .notifications: AppNotificationsPage(model: model)
    case .terminal: AppTerminalPage(model: model)
    case .worktrees: AppWorktreesPage(model: model)
    case .agents, .hooksCreate, .hooksDelete, .hooksEnvironment, .integrations: EmptyView()
    }
  }

  @ViewBuilder
  private func projectPage(_ project: Project) -> some View {
    switch location.section {
    case .agents: ProjectAgentsPage(model: model, project: project)

    case .general: ProjectGeneralPage(model: model, project: project)

    case .hooksCreate, .hooksDelete, .hooksEnvironment:
      ProjectHooksPage(model: model, project: project, section: location.section)

    case .integrations: ProjectIntegrationsPage(model: model, project: project)

    case .terminal: ProjectTerminalPage(model: model, project: project)

    case .worktrees: ProjectWorktreesPage(model: model, project: project)

    case .agentHooks, .agentSettings, .appearance, .notifications: EmptyView()
    }
  }
}
