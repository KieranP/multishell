import MultishellAppCore
import MultishellCore
import SwiftUI

/// Each names this group, so a click in one never acts in another.
/// Outside the scroller, so a full strip cannot hide them.
struct TabStripButtons: View {
  let model: AppModel
  let groupID: TabGroup.ID
  let isFocusedGroup: Bool
  let showsSplits: Bool
  let theme: Theme

  var body: some View {
    HStack(spacing: 0) {
      NewTabMenu(model: model, groupID: groupID, isFocusedGroup: isFocusedGroup, theme: theme)
      if showsSplits {
        // The same family the tab's own icon uses for a split tab.
        splitButton(.horizontal, symbol: PaneSymbol.split)
        splitButton(.vertical, symbol: "rectangle.split.1x2")
      }
    }
  }

  /// Splits the tab this group shows, whichever group the keyboard is in.
  private func splitButton(_ axis: SplitAxis, symbol: String) -> some View {
    Button {
      model.splitActivePane(axis, in: groupID)
    } label: {
      Image(systemName: symbol)
        .font(.system(size: model.metrics.icon, weight: .medium))
        .foregroundStyle(theme.textSecondary)
        .frame(width: model.metrics.splitButtonWidth, height: model.metrics.tabHeight)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(splitHelp(for: axis))
    .accessibilityLabel(axis == .horizontal ? t("tab.split-right") : t("tab.split-down"))
  }

  /// The keystrokes split the focused group, so only that group's buttons
  /// are what they do.
  private func splitHelp(for axis: SplitAxis) -> String {
    switch (axis, isFocusedGroup) {
    case (.horizontal, true): t("tab.split-right-here")
    case (.horizontal, false): t("tab.split-right-in-group")
    case (.vertical, true): t("tab.split-down-here")
    case (.vertical, false): t("tab.split-down-in-group")
    }
  }
}
