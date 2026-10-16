import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's filter: a substring of the path, folded as the sidebar folds.
struct FilesPanelFilterField: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    let text = Binding(
      get: { model.filesPanelState(of: worktreeID).filterText },
      set: { model.setFilesPanelFilterText($0, in: worktreeID) },
    )
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(metrics.font(size: metrics.small))
        .foregroundStyle(theme.textTertiary)
        .accessibilityHidden(true)
      TextField(t("files-panel.filter"), text: text)
        .textFieldStyle(.plain)
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .onExitCommand { text.wrappedValue = "" }
      if !text.wrappedValue.isEmpty {
        ClearFilterButton(help: t("files-panel.clear-filter"), theme: theme, metrics: metrics) {
          text.wrappedValue = ""
        }
      }
    }
    .filterWell(theme: theme, metrics: metrics)
    .padding(.top, 8)
    .padding(.bottom, 6)
  }
}
