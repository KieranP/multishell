import MultishellAppCore
import MultishellCore
import SwiftUI

/// A worktree's columns of tabs, side by side: a one-axis `WeightedSplit`,
/// columns only ever running left to right. Divider drags are written back.
struct TabGroupsView: View {
  @Bindable var model: AppModel
  let worktree: Worktree
  let theme: Theme

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
      drag: $model.tabDrag
    )
  }
}
