import MultishellAppCore
import MultishellCore
import SwiftUI

/// One group of a worktree: its tab strip, the shown tab's pane tree, and
/// the two drop bands down its edges while a tab is dragged.
struct TabGroupView: View {
  let model: AppModel
  let group: TabGroup
  /// Whether the keystrokes go here. Its focused pane is the one that wears
  /// the ring; every other pane in the window fades by the theme's amount.
  let isFocusedGroup: Bool
  /// Where this group sits, for the strip's screen-reader label.
  let position: Int
  let groupCount: Int
  let theme: Theme
  @Binding var drag: TabDragState

  var body: some View {
    VStack(spacing: 0) {
      TabStrip(
        model: model,
        group: group,
        tabs: model.workspace.tabs(in: group.id),
        isFocusedGroup: isFocusedGroup,
        groupLabel: AccessibilityText.tabGroup(
          position: position, of: groupCount, isFocused: isFocusedGroup),
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
      isFocusedGroup: isFocusedGroup,
      showsFocusRing: model.showsFocusRing(in: tab),
      theme: theme
    )
    .id(tab.id)
    .overlay {
      if drag.isDragging {
        GroupDropBands(model: model, group: group, drag: $drag)
      }
    }
  }
}
