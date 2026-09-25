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
            ProjectGeneralTab(model: model, project: project)
          },
          .init(t("settings.worktrees"), symbol: "arrow.trianglehead.branch") {
            ProjectWorktreesTab(model: model, project: project)
          },
          .init(t("settings.hooks"), symbol: "bolt.horizontal") {
            ProjectHooksTab(model: model, project: project)
          },
          .init(t("settings.terminal"), symbol: "terminal") {
            ProjectTerminalTab(model: model, project: project)
          },
          .init(t("label.agents"), symbol: "sparkles") {
            ProjectAgentTab(model: model, project: project)
          },
        ], firstTabToken: firstTabToken
      )
      .frame(width: SettingsView.windowSize.width, height: SettingsView.windowSize.height)
      .navigationTitle(t("window.project-settings-title", project.name))
      // This window is its own scene, so a removal asked for here has to
      // be confirmed here; the workspace window's dialog would be behind it.
      .projectRemovalDialog(model: model, source: .settings)
      .settingsWindowReset(
        on: { platform.mainWindow?.screen }, showFirstTab: { firstTabToken = UUID() })
    } else {
      // The project was removed while this window was open.
      Color.clear.frame(width: 1, height: 1).onAppear { dismiss() }
    }
  }
}
