import MultishellAppCore
import MultishellCore
import SwiftUI

/// A worktree's groups of tabs, side by side: a one-axis `WeightedSplit`,
/// groups only ever running left to right. Divider drags are written back.
struct WorktreeTabGroups: View {
  @Bindable var model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    let groups = model.workspace.groups(in: worktree.id)
    let focusedID = model.workspace.focusedGroup(in: worktree.id)?.id
    if groups.count == 1, let only = groups.first {
      groupView(only, at: 1, of: 1, isFocusedGroup: true)
    } else {
      WeightedSplit(
        axis: .horizontal,
        weights: groups.map(\.weight),
        dividerColor: theme.hairline,
        gutterColor: theme.chromeColor,
        onWeightsChange: { model.setGroupWeights($0, in: worktree.id) },
        content: {
          ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            groupView(
              group, at: index + 1, of: groups.count, isFocusedGroup: group.id == focusedID)
          }
        }
      )
    }
  }

  private func groupView(
    _ group: TabGroup, at position: Int, of count: Int, isFocusedGroup: Bool
  ) -> some View {
    TabGroupView(
      model: model,
      group: group,
      isFocusedGroup: isFocusedGroup,
      position: position,
      groupCount: count,
      theme: theme,
      drag: $model.tabDrag
    )
  }
}
