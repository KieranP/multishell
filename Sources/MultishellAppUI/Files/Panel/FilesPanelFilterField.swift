import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's filter: a substring of the path, folded as the sidebar folds,
/// with `accessory` beside its well.
struct FilesPanelFilterField<Accessory: View>: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let theme: Theme
  @ViewBuilder let accessory: () -> Accessory

  @FocusState private var isFocused: Bool

  var body: some View {
    let metrics = model.metrics
    let text = Binding(
      get: { model.filesPanelState(of: worktreeID).filterText },
      set: { model.setFilesPanelFilterText($0, in: worktreeID) },
    )
    HStack(spacing: UIMetrics.filesPanelFilterAccessoryGap) {
      field(text: text, metrics: metrics)
        .filterWell(palette: theme.filesPanel, metrics: metrics, listSideInset: 0)
      accessory()
    }
    .padding(.horizontal, UIMetrics.filesPanelListSideInset)
    .padding(.top, 8)
    .padding(.bottom, 6)
  }

  private func field(text: Binding<String>, metrics: UIMetrics) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(metrics.font(size: metrics.small))
        .foregroundStyle(theme.filesPanel.textTertiary)
        .accessibilityHidden(true)
      TextField("", text: text)
        .textFieldStyle(.plain)
        .fieldPrompt(
          t("files-panel.filter"),
          isShown: text.wrappedValue.isEmpty,
          color: theme.filesPanel.textTertiary,
        )
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(theme.filesPanel.text)
        .focused($isFocused)
        .fieldEditorColors(
          selection: theme.filesPanel.color(.selectionBackground),
          caret: theme.filesPanel.text,
          isFocused: isFocused,
        )
        .onExitCommand { text.wrappedValue = "" }
      if !text.wrappedValue.isEmpty {
        ClearFilterButton(
          help: t("files-panel.clear-filter"),
          palette: theme.filesPanel,
          metrics: metrics,
        ) {
          text.wrappedValue = ""
        }
      }
    }
  }
}
