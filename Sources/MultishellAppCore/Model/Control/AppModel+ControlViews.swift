import Foundation
import MultishellCore

extension AppModel {
  /// Both settings words open the one window, `settings` on All Projects and `project-settings`
  /// on the project named, else the one shown, else the selection's; see Docs/design/agents.md.
  func replyToShowView(_ view: ControlView, project id: String?) -> ControlReply {
    switch view {
    case .agentBoard: showAgentBoard()
    case .allTerminals: setShowsAllTerminals(true)

    case .settings:
      setSettingsScope(.allProjects)
      platform.show(.settings)

    case .projectSettings:
      switch settingsScopeAsked(inProject: true, project: id) {
      // A project named opens as its menu item does; none brings the window up as it is.
      case .success(let scope) where id != nil || scope != settingsLocation.scope:
        showSettingsUnfiltered(.general, in: scope)

      case .success:
        break

      case .failure(let refusal):
        return .refused(refusal)
      }
      platform.show(.settings)
    }
    return .done
  }

  /// As a sidebar row's click, on All Projects or a project as the request
  /// names it, a split page opening its first part; nothing moves on a refusal.
  func replyToShowSettingsPage(
    _ page: ControlSettingsPage,
    inProject: Bool,
    project id: String?,
  ) -> ControlReply {
    let scope: SettingsScope
    switch settingsScopeAsked(inProject: inProject, project: id) {
    case .success(let asked): scope = asked
    case .failure(let refusal): return .refused(refusal)
    }
    let asked = SettingsSection(page)
    let sections = asked.page.sections(in: scope)
    let opened = sections.contains(asked) ? asked : asked.isPart ? nil : sections.first
    guard let section = opened else {
      let listed = SettingsPage.pages(in: scope).flatMap { $0.controlSettingsPages(in: scope) }
      return .refused(.noSettingsPage(page, pages: listed))
    }
    showSettingsUnfiltered(section, in: scope)
    platform.show(.settings)
    return .done
  }

  /// Whose settings a request asks for: a project named, else the one shown,
  /// else the selection's, refused where none of those is to be had.
  private func settingsScopeAsked(
    inProject: Bool,
    project id: String?,
  ) -> Result<SettingsScope, ControlRefusal> {
    guard inProject else { return .success(.allProjects) }
    if let id {
      guard let project = project(withControlID: id) else { return .failure(.noProject(id: id)) }
      return .success(.project(project.id))
    }
    if settingsLocation.scope != .allProjects { return .success(settingsLocation.scope) }
    guard let project = settingsWindowFallbackProject else { return .failure(.noProjectChosen) }
    return .success(.project(project.id))
  }

  /// `project-settings` closes the window only while it shows a project.
  func replyToHideView(_ view: ControlView) -> ControlReply {
    switch view {
    case .agentBoard: hideAgentBoard()
    case .allTerminals: setShowsAllTerminals(false)
    case .settings: platform.close(.settings)

    case .projectSettings:
      if settingsLocation.scope != .allProjects { platform.close(.settings) }
    }
    return .done
  }
}
