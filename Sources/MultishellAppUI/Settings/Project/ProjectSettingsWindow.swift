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

  @State private var firstPageToken = UUID()

  var body: some View {
    if let project = model.workspace.project(projectID) {
      ToolbarPages(
        pages: [
          .init(.general) {
            ProjectGeneralPage(model: model, project: project)
          },
          .init(.worktrees) {
            ProjectWorktreesPage(model: model, project: project)
          },
          .init(.hooks) {
            ProjectHooksPage(model: model, project: project)
          },
          .init(.terminal) {
            ProjectTerminalPage(model: model, project: project)
          },
          .init(.agents) {
            ProjectAgentsPage(model: model, project: project)
          },
        ], firstPageToken: firstPageToken
      )
      .settingsWindow(platform: platform, showFirstPage: { firstPageToken = UUID() })
      .navigationTitle(t("window.project-settings-title", project.name))
      // This window is its own scene, so a removal asked for here has to
      // be confirmed here; the workspace window's dialog would be behind it.
      .projectRemovalDialog(model: model, source: .settings)
    } else {
      // The project was removed while this window was open.
      Color.clear.frame(width: 1, height: 1).onAppear { dismiss() }
    }
  }
}
