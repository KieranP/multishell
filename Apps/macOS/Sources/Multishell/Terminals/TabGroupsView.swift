import MultishellAppCore
import MultishellCore
import SwiftUI

/// A worktree's columns of tabs, side by side.
///
/// Columns are only ever left to right, so this is a `WeightedSplit` on one
/// axis rather than a tree: a tab that wants a pane below it splits, which
/// `PaneTreeView` draws inside whichever column the tab is in. Divider drags
/// are written back to the groups' weights the way a split's are, so a
/// layout survives relaunch.
struct TabGroupsView: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  /// One value for every column; see `TabDragState`.
  @State private var drag = TabDragState()

  var body: some View {
    let groups = model.workspace.groups(in: worktree.id)
    let focusedID = model.workspace.focusedGroup(in: worktree.id)?.id
    if groups.count == 1, let only = groups.first {
      column(only, at: 1, of: 1, isFocused: true)
    } else {
      WeightedSplit(
        axis: .horizontal,
        weights: groups.map(\.weight),
        divider: theme.hairline,
        background: theme.chromeColor,
        onWeightsChange: { model.setGroupWeights($0, in: worktree.id) },
        content: {
          ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            column(
              group, at: index + 1, of: groups.count, isFocused: group.id == focusedID)
          }
        }
      )
    }
  }

  private func column(
    _ group: TabGroup, at position: Int, of count: Int, isFocused: Bool
  ) -> some View {
    TabColumnView(
      model: model,
      group: group,
      isFocused: isFocused,
      position: position,
      columnCount: count,
      theme: theme,
      drag: $drag
    )
  }
}
