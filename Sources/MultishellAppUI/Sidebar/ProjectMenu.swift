import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project row's context menu. A view of its own rather than a builder on
/// the sidebar, so its lookups run when the menu does, not on every render.
struct ProjectMenu: View {
  let model: AppModel
  let project: Project

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button(t("action.new-worktree")) { model.requestNewWorktree(in: project) }
    Button(t("action.refresh")) { Task { await model.refreshRequested(project) } }
    // Refresh asks git what is on disk; Fetch asks the remote, which is
    // what the merged badges are measured against.
    Button(t("action.fetch")) { Task { await model.fetch(project) } }
      .disabled(model.isFetching(project))
    Divider()
    Button(t("action.project-settings")) {
      model.settingsProjectID = project.id
      openWindow(id: ProjectSettingsWindow.windowID)
    }
    Button(t("action.reveal-in-finder")) { model.revealInFileBrowser(project.path) }
    Divider()
    Button(t("action.remove-project"), role: .destructive) {
      model.requestProjectRemoval(project, from: .workspace)
    }
  }
}
