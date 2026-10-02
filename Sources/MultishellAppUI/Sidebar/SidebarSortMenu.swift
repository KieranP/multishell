import MultishellAppCore
import MultishellCore
import SwiftUI

/// The global order and the active-first toggle; a project's override stays
/// in its settings. See Docs/design/worktrees.md.
struct SidebarSortMenu: View {
  let model: AppModel
  let theme: Theme
  let metrics: UIMetrics

  @State private var isHovered = false

  var body: some View {
    Menu {
      Picker(
        t("sidebar.sort-worktrees"),
        selection: model.setting(\.worktreeSortOrder, write: model.setWorktreeSortOrder)
      ) {
        ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
      }
      .pickerStyle(.inline)
      Divider()
      Toggle(
        t("worktrees.active-first"),
        isOn: model.setting(
          \.showsActiveWorktreesFirst, write: model.setShowsActiveWorktreesFirst))
    } label: {
      Image(systemName: "arrow.up.arrow.down")
        .font(.system(size: metrics.badge))
        .foregroundStyle(isHovered ? theme.textSecondary : theme.textTertiary.opacity(0.7))
        .frame(width: UIMetrics.sidebarRowButtonWidth, height: UIMetrics.sectionHeaderHeight)
        // Painted: a menu is hit-tested by its label's ink, and the glyph
        // alone is a small target. As the strip's + does.
        .background(theme.sidebarColor)
        .contentShape(.rect)
    }
    .glyphMenuStyle()
    .fixedSize()
    .onHover { isHovered = $0 }
    .help(t("sidebar.sort-worktrees"))
    .accessibilityLabel(t("sidebar.sort-worktrees"))
  }
}
