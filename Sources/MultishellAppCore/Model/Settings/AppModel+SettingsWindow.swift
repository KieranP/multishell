import Foundation
import MultishellCore

extension AppModel {
  /// Whose settings the window shows, as its title names them.
  public var settingsScopeName: String { settingsScopeName(of: settingsLocation.scope) }

  /// The header's right end: that these apply to every project, or which
  /// project's folder they belong to.
  public var settingsHeaderCaption: String {
    switch settingsLocation.scope {
    case .allProjects: t("settings.applies-to-all")
    case .project(let id): workspace.project(id)?.path.path.abbreviatingHomeDirectory() ?? ""
    }
  }

  /// Whose settings a scope holds, as the window's title names them.
  public func settingsScopeName(of scope: SettingsScope) -> String {
    switch scope {
    case .allProjects: t("settings.all-projects")
    case .project(let id): workspace.project(id)?.name ?? ""
    }
  }

  /// A sidebar row, or a project's Global column opening the page that sets it.
  public func showSettings(_ section: SettingsSection, in scope: SettingsScope) {
    move(to: SettingsLocation(scope: scope, section: section))
  }

  /// The sidebar's arrow keys, a row up or down through the pages it lists.
  public func stepSettingsSection(by offset: Int, among pages: [SettingsPage]) {
    move(to: settingsLocation.stepped(by: offset, among: pages))
  }

  /// The sidebar's scope menu, keeping the page where the scope has it.
  public func setSettingsScope(_ scope: SettingsScope) {
    move(to: settingsLocation.moved(to: scope))
  }

  /// A project's own menu asking for its settings, which the window opened
  /// after this shows from its first page.
  public func showSettings(of project: Project) {
    showSettingsUnfiltered(.general, in: .project(project.id))
  }

  /// A request from outside the window, which empties the search so the page
  /// asked for has its sidebar row.
  func showSettingsUnfiltered(_ section: SettingsSection, in scope: SettingsScope) {
    setIfChanged(\.settingsSearchText, "")
    showSettings(section, in: scope)
  }

  /// The window closing, or the project it shows removed: back on All
  /// Projects, its search empty as any change of scope leaves it.
  public func returnSettingsToAllProjects() {
    setIfChanged(\.settingsLocation, .start)
    setIfChanged(\.settingsSearchText, "")
  }

  public func setSettingsSearchText(_ text: String) {
    setIfChanged(\.settingsSearchText, text)
  }

  /// Another scope empties the search, which its pages may not match.
  private func move(to location: SettingsLocation) {
    if location.scope != settingsLocation.scope { setIfChanged(\.settingsSearchText, "") }
    setIfChanged(\.settingsLocation, location)
  }
}
