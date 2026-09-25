import MultishellAppCore
import MultishellCore
import SwiftUI

/// One column of a worktree: its tab strip, the shown tab's pane tree, and
/// the two drop bands down its edges while a tab is dragged.
struct TabColumnView: View {
  let model: AppModel
  let group: TabGroup
  /// Whether the keystrokes go here. Its focused pane is the one that wears
  /// the ring; every other pane in the window fades by the theme's amount.
  let isFocused: Bool
  /// Where this column sits, for the strip's screen-reader label.
  let position: Int
  let columnCount: Int
  let theme: Theme
  @Binding var drag: TabDragState

  var body: some View {
    VStack(spacing: 0) {
      TabBar(
        model: model,
        group: group,
        tabs: model.workspace.tabs(in: group.id),
        isFocused: isFocused,
        columnLabel: AccessibilityText.tabGroup(
          position: position, of: columnCount, isFocused: isFocused),
        theme: theme,
        drag: $drag
      )
      if let tab = model.workspace.activeTab(in: group) {
        panes(of: tab)
      } else {
        Spacer()
      }
    }
  }

  /// The tab's panes, with the drop bands over them. `.id(tab.id)` so a
  /// switch builds a fresh tree rather than rebinding these surfaces.
  private func panes(of tab: TerminalTab) -> some View {
    PaneTreeView(
      model: model,
      tabID: tab.id,
      node: tab.root,
      focusedSessionID: tab.focusedSessionID,
      isFocusedColumn: isFocused,
      showsFocusRing: tab.isSplit || columnCount > 1,
      theme: theme
    )
    .id(tab.id)
    .overlay {
      if drag.isDragging {
        TabGroupBands(model: model, group: group, drag: $drag)
      }
    }
  }
}
