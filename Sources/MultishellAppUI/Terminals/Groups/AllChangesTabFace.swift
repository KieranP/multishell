import MultishellAppCore
import MultishellCore
import SwiftUI

/// The All changes tab in the strip: a plus-minus glyph, its title, a bubble
/// counting the worktree's comments to send.
struct AllChangesTabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: AllChangesTab
  let isFocusedGroup: Bool
  let theme: Theme

  var body: some View {
    let title = model.title(of: tab)
    let metrics = model.metrics
    DiffTabFace(
      model: model,
      group: group,
      tabID: tab.id,
      title: title,
      isTitleStruck: false,
      pendingComments: model.pendingReviewCommentCount(of: tab),
      accessibilityLabel: AccessibilityText.allChangesTab(
        title: title,
        isShown: tab.id == group.shownTabID,
      ),
      isFocusedGroup: isFocusedGroup,
      theme: theme,
    ) { tint, _, _ in
      Image(systemName: AllChangesGlyph.symbolName)
        .font(metrics.font(size: metrics.glyph))
        .foregroundStyle(tint)
        .frame(width: metrics.paneGlyphSize, height: metrics.paneGlyphSize)
        .accessibilityHidden(true)
    } menu: {
      TabMoveAndCloseActions(model: model, tabID: tab.id, groupID: tab.groupID) {
        model.closeTab(tab.id)
      }
    }
  }
}
