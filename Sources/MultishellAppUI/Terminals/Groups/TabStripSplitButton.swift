import MultishellAppCore
import MultishellCore
import SwiftUI

/// Splits the tab this group shows, whichever group the keyboard is in.
struct TabStripSplitButton: View {
  let model: AppModel
  let groupID: TabGroup.ID
  let axis: SplitAxis
  let symbol: String
  let isFocusedGroup: Bool
  let theme: Theme

  @State private var isHovered = false

  var body: some View {
    // Unlit by its click, as an alert it can raise hides the pointer's exit.
    Button {
      isHovered = false
      model.splitActivePane(axis, in: groupID)
    } label: {
      Image(systemName: symbol)
        .font(model.metrics.font(size: model.metrics.glyph, weight: .medium))
        .frame(width: model.metrics.splitButtonWidth, height: model.metrics.tabHeight)
        .glyphHover(
          isHovered,
          palette: theme.tabBar,
          resting: theme.tabBar.textSecondary,
          inset: model.metrics.stripButtonHoverInset,
        )
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!model.canSplitShownTab(in: groupID))
    // Outside `disabled`, so a split enabled under a resting pointer hears it.
    .tracksHover($isHovered)
    .help(TabStripButtonText.splitHelp(axis, isFocusedGroup: isFocusedGroup))
    .accessibilityLabel(TabStripButtonText.splitLabel(axis))
  }
}
