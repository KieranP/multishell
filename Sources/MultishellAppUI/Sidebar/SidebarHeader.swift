import MultishellCore
import SwiftUI

/// The strip above the tree, leaving room for the traffic lights: the title
/// bar is hidden. Folder-plus, three identical glyphs otherwise reading as one.
struct SidebarHeader: View {
  let isFiltering: Bool
  let theme: Theme
  let toggleFilter: () -> Void
  let addProject: () -> Void

  var body: some View {
    HStack(spacing: 2) {
      Spacer()
      button("magnifyingglass", help: t("sidebar.filter-projects"), action: toggleFilter)
        .foregroundStyle(isFiltering ? theme.textPrimary : theme.textSecondary)
      button("folder.badge.plus", help: t("sidebar.add-project"), action: addProject)
        .foregroundStyle(theme.textSecondary)
    }
    .windowHeader()
  }

  private func button(
    _ symbol: String, help: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .medium))
        .frame(width: 28, height: 28)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(help)
  }
}
