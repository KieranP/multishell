import MultishellAppCore
import MultishellCore
import SwiftUI

/// Per-project settings, as a window that matches Multishell > Settings:
/// icon tabs in the toolbar, changes applied as they are made, closed with
/// the window's own close button. One file per tab beside this one.
struct ProjectSettingsWindow: View {
  static let windowID = "project-settings"

  let model: AppModel
  let projectID: Project.ID

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let project = model.workspace.project(projectID) {
      ToolbarTabs(tabs: [
        .init("General", symbol: "gearshape") {
          ProjectGeneralTab(model: model, project: project)
        },
        .init("Worktrees", symbol: "arrow.trianglehead.branch") {
          ProjectWorktreesTab(model: model, project: project)
        },
        .init("Hooks", symbol: "bolt.horizontal") {
          ProjectHooksTab(model: model, project: project)
        },
        .init("Terminal", symbol: "terminal") {
          ProjectTerminalTab(model: model, project: project)
        },
        .init("Agents", symbol: "sparkles") { ProjectAgentTab(model: model, project: project) },
      ])
      .frame(width: 560, height: 480)
      .navigationTitle("\(project.name) Settings")
      // This window is its own scene, so a removal asked for here has to
      // be confirmed here; the workspace window's dialog would be behind it.
      .projectRemovalDialog(model: model, source: .settings)
    } else {
      // The project was removed while this window was open.
      Color.clear.frame(width: 1, height: 1).onAppear { dismiss() }
    }
  }
}
