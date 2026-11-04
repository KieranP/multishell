import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// A file tab in the strip: a document glyph with its change's dot, the title
/// struck through once the file has gone, and no rename.
struct FileTabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: FileTab
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
    let change = model.changeKind(of: tab)
    return HStack(spacing: UIMetrics.tabItemGap) {
      leadingGlyph(change: change, tint: textColor)
      Text(title)
        .font(
          model.metrics.font(size: model.metrics.secondary, weight: isShown ? .medium : .regular)
        )
        .strikethrough(model.isFileGone(of: tab.id))
        .foregroundStyle(textColor)
        .lineLimit(1)
        .truncationMode(.head)
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
    .help(tab.path)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(AccessibilityText.fileTab(title: title, isShown: isShown, change: change))
    .selectableButtonTraits(isSelected: isShown)
    .contextMenu {
      FileTabActions(model: model, tab: tab) { model.closeTab(tab.id) }
    }
  }

  private func leadingGlyph(change: StatusChange.Kind?, tint: Color) -> some View {
    let size = model.metrics.paneGlyphSize
    return Image(systemName: "doc.text")
      .font(model.metrics.font(size: model.metrics.glyph))
      .foregroundStyle(tint)
      .frame(width: size, height: size)
      .cornerBadge(
        onGlyphOf: size,
        ringFill: palette.background,
        ringWash: hoverWash,
        change.map { change in
          Circle()
            .fill(theme.color(for: change))
            .frame(
              width: UIMetrics.cornerBadgeSize(onGlyphOf: size),
              height: UIMetrics.cornerBadgeSize(onGlyphOf: size),
            )
        },
      )
      .accessibilityHidden(true)
  }
}
