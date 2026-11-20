import MultishellCore
import SwiftUI

/// The strip above the tree, leaving room for the traffic lights: the title
/// bar is hidden. New Project is a folder-plus so it does not read as a row's +.
struct SidebarHeader: View {
  let showsFilterField: Bool
  /// The buttons' tooltips, naming their keys in force.
  let filterProjectsHelp: String
  let newProjectHelp: String
  let theme: Theme
  let toggleFilter: () -> Void
  let newProject: () -> Void

  var body: some View {
    HStack(spacing: 2) {
      Spacer()
      HeaderGlyphButton(
        symbol: "magnifyingglass",
        help: filterProjectsHelp,
        palette: theme.projectsPanel,
        resting: showsFilterField ? theme.projectsPanel.text : theme.projectsPanel.textSecondary,
        action: toggleFilter,
      )
      HeaderGlyphButton(
        symbol: "folder.badge.plus",
        help: newProjectHelp,
        palette: theme.projectsPanel,
        resting: theme.projectsPanel.textSecondary,
        opensAWindow: true,
        action: newProject,
      )
    }
    .windowHeader()
  }
}
