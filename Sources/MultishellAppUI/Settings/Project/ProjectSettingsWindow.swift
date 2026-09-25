import MultishellAppCore
import MultishellCore
import SwiftUI

/// Per-project settings, as a window matching Multishell > Settings: icon
/// tabs, changes applied as made. One file per tab beside this one.
struct ProjectSettingsWindow: View {
  static let windowID = "project-settings"

  let model: AppModel
  let platform: MacPlatform
  let projectID: Project.ID

  @Environment(\.dismiss) private var dismiss

  @State private var firstTabToken = UUID()

  var body: some View {
    if let project = model.workspace.project(projectID) {
      ToolbarTabs(
        tabs: [
          .init(t("settings.general"), symbol: "gearshape") {
            ProjectGeneralPage(model: model, project: project)
          },
          .init(t("settings.worktrees"), symbol: "arrow.trianglehead.branch") {
            ProjectWorktreesPage(model: model, project: project)
          },
          .init(t("settings.hooks"), symbol: "bolt.horizontal") {
            ProjectHooksPage(model: model, project: project)
          },
          .init(t("settings.terminal"), symbol: "terminal") {
            ProjectTerminalPage(model: model, project: project)
          },
          .init(t("label.agents"), symbol: "sparkles") {
            ProjectAgentsPage(model: model, project: project)
          },
        ], firstTabToken: firstTabToken
      )
      .frame(width: SettingsWindow.size.width, height: SettingsWindow.size.height)
      .navigationTitle(t("window.project-settings-title", project.name))
      // This window is its own scene, so a removal asked for here has to
      // be confirmed here; the workspace window's dialog would be behind it.
      .projectRemovalDialog(model: model, source: .settings)
      .settingsWindowReset(
        on: { platform.mainWindow?.screen }, showFirstPage: { firstTabToken = UUID() })
    } else {
      // The project was removed while this window was open.
      Color.clear.frame(width: 1, height: 1).onAppear { dismiss() }
    }
  }
}
