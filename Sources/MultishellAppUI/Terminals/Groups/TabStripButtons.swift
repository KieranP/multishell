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

  private func splitButton(_ axis: SplitAxis, symbol: String) -> some View {
    TabStripSplitButton(
      model: model,
      groupID: groupID,
      axis: axis,
      symbol: symbol,
      isFocusedGroup: isFocusedGroup,
      theme: theme,
    )
  }
}
