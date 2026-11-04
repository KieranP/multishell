import MultishellCore
import SwiftUI

/// The strip above the tree, leaving room for the traffic lights: the title
/// bar is hidden. Add Project is a folder-plus so it does not read as a row's +.
struct SidebarHeader: View {
  let showsFilterField: Bool
  let theme: Theme
  let toggleFilter: () -> Void
  let addProject: () -> Void

  var body: some View {
    HStack(spacing: 2) {
      Spacer()
      HeaderGlyphButton(
        symbol: "magnifyingglass",
        help: t("sidebar.filter-projects"),
        palette: theme.projectsPanel,
        resting: showsFilterField ? theme.projectsPanel.text : theme.projectsPanel.textSecondary,
        action: toggleFilter,
      )
      HeaderGlyphButton(
        symbol: "folder.badge.plus",
        help: t("sidebar.add-project"),
        palette: theme.projectsPanel,
        resting: theme.projectsPanel.textSecondary,
        opensAWindow: true,
        action: addProject,
      )
    }
    .windowHeader()
  }
}
