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
      button("magnifyingglass", help: t("sidebar.filter-projects"), action: toggleFilter)
        .foregroundStyle(showsFilterField ? theme.textPrimary : theme.textSecondary)
      button("folder.badge.plus", help: t("sidebar.add-project"), action: addProject)
        .foregroundStyle(theme.textSecondary)
    }
    .windowHeader()
  }

  private func button(
    _ symbol: String, help: String, action: @escaping () -> Void
  ) -> some View {
    PlainGlyphButton(help: help, action: action) {
      Image(systemName: symbol)
        .font(.system(size: UIMetrics.headerGlyphSize, weight: .medium))
        .frame(width: UIMetrics.headerGlyphButtonSide, height: UIMetrics.headerGlyphButtonSide)
    }
  }
}
