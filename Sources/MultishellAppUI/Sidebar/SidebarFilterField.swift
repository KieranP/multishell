import MultishellCore
import SwiftUI

/// The field the tree is filtered by, hidden until asked for. It takes
/// the keyboard as it appears, so the magnifier is one click.
struct SidebarFilterField: View {
  @Binding var text: String
  let isFiltering: Bool
  let theme: Theme
  let metrics: UIMetrics
  let close: () -> Void

  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 6) {
      TextField("", text: $text)
        .textFieldStyle(.plain)
        .fieldPrompt(
          t("sidebar.filter"),
          isShown: text.isEmpty,
          color: theme.projectsPanel.textTertiary,
        )
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(theme.projectsPanel.text)
        .focused($isFocused)
        // A turn later: focus does not take on a field the hierarchy has not
        // installed yet.
        .task { isFocused = true }
        .onExitCommand(perform: close)
      if isFiltering {
        ClearFilterButton(
          help: t("sidebar.clear-filter"),
          palette: theme.projectsPanel,
          metrics: metrics,
        ) {
          text = ""
          isFocused = true
        }
      }
    }
    .filterWell(palette: theme.projectsPanel, metrics: metrics)
  }
}
