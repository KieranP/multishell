import MultishellAppCore
import MultishellCore
import SwiftUI

/// A tab of rows in the strip, a file's or All changes: its glyph, its title, a
/// bubble counting comments to send, no rename.
struct DiffTabFace<Glyph: View, Menu: View>: View {
  let model: AppModel
  let group: TabGroup
  let tabID: WorkspaceTab.ID
  let title: String
  let isTitleStruck: Bool
  let pendingComments: Int
  let accessibilityLabel: String
  let isFocusedGroup: Bool
  let theme: Theme
  /// Drawn in the title's colour, ringed where it carries a badge on the face's own fill.
  @ViewBuilder let glyph: (_ tint: Color, _ ring: AreaPalette, _ wash: Color?) -> Glyph
  @ViewBuilder let menu: () -> Menu

  @State private var isHovered = false

  private var isShown: Bool { tabID == group.shownTabID }
  private var hoverWash: Color? { theme.hoverWash(onShownTab: isShown, isHovered: isHovered) }
  private var palette: AreaPalette { isShown ? theme.fileTab : theme.tabBar }

  var body: some View {
    let isActive = isShown && isFocusedGroup
    let textColor = isActive ? palette.text : palette.textSecondary
    return HStack(spacing: UIMetrics.tabItemGap) {
      glyph(textColor, palette, hoverWash)
      Text(title)
        .font(
          model.metrics.font(size: model.metrics.secondary, weight: isShown ? .medium : .regular)
        )
        .strikethrough(isTitleStruck)
        .foregroundStyle(textColor)
        .lineLimit(1)
        .truncationMode(.head)
      if pendingComments > 0 {
        ReviewCountBadge(count: pendingComments, theme: theme, metrics: model.metrics)
      }
      Spacer(minLength: 0)
      TabCloseButton(
        metrics: model.metrics,
        palette: palette,
        stripPalette: theme.tabBar,
        isVisible: TabCloseButtonVisibility.isVisible(onShownTab: isShown, isHovered: isHovered),
        close: { model.closeTab(tabID) },
      )
    }
    .tabFace(
      isShown: isShown,
      wash: hoverWash,
      shownFill: theme.fileTab.background,
      theme: theme,
      activate: { model.activateTab(tabID) },
      close: { model.closeTab(tabID) },
    )
    .tracksHover($isHovered)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
    .selectableButtonTraits(isSelected: isShown)
    .contextMenu { menu() }
  }
}
