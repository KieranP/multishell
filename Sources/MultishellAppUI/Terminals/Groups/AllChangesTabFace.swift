import MultishellAppCore
import MultishellCore
import SwiftUI

/// The All changes tab in the strip: a plus-minus glyph, its title, a bubble
/// counting the worktree's comments to send, no rename.
struct AllChangesTabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: AllChangesTab
  let isFocusedGroup: Bool
  let theme: Theme

  @State private var isHovered = false

  private var isShown: Bool { tab.id == group.shownTabID }
  private var hoverWash: Color? { theme.hoverWash(onShownTab: isShown, isHovered: isHovered) }
  private var palette: AreaPalette { isShown ? theme.fileTab : theme.tabBar }

  var body: some View {
    let isActive = isShown && isFocusedGroup
    let textColor = isActive ? palette.text : palette.textSecondary
    let title = model.title(of: tab)
    return HStack(spacing: UIMetrics.tabItemGap) {
      Image(systemName: AllChangesGlyph.symbolName)
        .font(model.metrics.font(size: model.metrics.glyph))
        .foregroundStyle(textColor)
        .frame(width: model.metrics.paneGlyphSize, height: model.metrics.paneGlyphSize)
        .accessibilityHidden(true)
      Text(title)
        .font(
          model.metrics.font(size: model.metrics.secondary, weight: isShown ? .medium : .regular)
        )
        .foregroundStyle(textColor)
        .lineLimit(1)
      let pendingComments = model.pendingReviewCommentCount(of: tab)
      if pendingComments > 0 {
        ReviewCountBadge(count: pendingComments, theme: theme, metrics: model.metrics)
      }
      Spacer(minLength: 0)
      TabCloseButton(
        metrics: model.metrics,
        palette: palette,
        stripPalette: theme.tabBar,
        isVisible: TabCloseButtonVisibility.isVisible(onShownTab: isShown, isHovered: isHovered),
        close: { model.closeTab(tab.id) },
      )
    }
    .tabFace(
      isShown: isShown,
      wash: hoverWash,
      shownFill: theme.fileTab.background,
      theme: theme,
      activate: { model.activateTab(tab.id) },
      close: { model.closeTab(tab.id) },
    )
    .tracksHover($isHovered)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(AccessibilityText.allChangesTab(title: title, isShown: isShown))
    .selectableButtonTraits(isSelected: isShown)
    .contextMenu {
      TabMoveAndCloseActions(model: model, tabID: tab.id, groupID: tab.groupID) {
        model.closeTab(tab.id)
      }
    }
  }
}
