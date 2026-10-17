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

  private var isShown: Bool { tab.id == group.shownTabID }
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
      if isActive { TabCloseButton(model: model, tabID: tab.id, palette: palette) }
    }
    .tabFace(
      isShown: isShown,
      shownFill: theme.fileTab.background,
      theme: theme,
      activate: { model.activateTab(tab.id) },
      close: { model.closeTab(tab.id) },
    )
    .help(tab.path)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(AccessibilityText.fileTab(title: title, isShown: isShown, change: change))
    .selectableButtonTraits(isSelected: isShown)
    .contextMenu {
      FileTabActions(model: model, tab: tab)
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
