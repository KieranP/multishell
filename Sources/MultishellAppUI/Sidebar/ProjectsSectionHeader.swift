import MultishellAppCore
import MultishellCore
import SwiftUI

/// The Projects label, with the sort menu at the + column's edge so the
/// setting sits beside the rows it orders.
struct ProjectsSectionHeader: View {
  let model: AppModel
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 6) {
      Text(t("sidebar.projects"))
        .font(.system(size: metrics.caption, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
      Spacer(minLength: 4)
      SidebarSortMenu(model: model, theme: theme, metrics: metrics)
    }
    .padding(.horizontal, UIMetrics.sidebarRowSideInset)
    .frame(height: UIMetrics.sectionHeaderHeight)
    .padding(.bottom, 2)
  }
}
