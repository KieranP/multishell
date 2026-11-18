import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// A file tab in the strip: a document glyph with its change's dot, the title struck
/// through once the file has gone, a bubble counting comments to send.
struct FileTabFace: View {
  let model: AppModel
  let group: TabGroup
  let tab: FileTab
  let isFocusedGroup: Bool
  let theme: Theme

  var body: some View {
    let title = model.title(of: tab)
    let change = model.changeKind(of: tab)
    DiffTabFace(
      model: model,
      group: group,
      tabID: tab.id,
      title: title,
      isTitleStruck: model.isFileGone(of: tab.id),
      pendingComments: model.pendingReviewCommentCount(of: tab),
      accessibilityLabel: AccessibilityText.fileTab(
        title: title,
        isShown: tab.id == group.shownTabID,
        change: change,
      ),
      isFocusedGroup: isFocusedGroup,
      theme: theme,
    ) { tint, ring, wash in
      leadingGlyph(change: change, tint: tint, ring: ring, wash: wash)
    } menu: {
      FileTabActions(model: model, tab: tab) { model.closeTab(tab.id) }
    }
    .help(tab.path)
  }

  private func leadingGlyph(
    change: StatusChange.Kind?,
    tint: Color,
    ring: AreaPalette,
    wash: Color?,
  ) -> some View {
    let size = model.metrics.paneGlyphSize
    let badgeScale = theme.stateDotScale
    let badgeDiameter = UIMetrics.scaledCornerBadgeSize(onGlyphOf: size, badgeScale: badgeScale)
    return Image(systemName: "doc.text")
      .font(model.metrics.font(size: model.metrics.glyph))
      .foregroundStyle(tint)
      .frame(width: size, height: size)
      .cornerBadge(
        onGlyphOf: size,
        badgeScale: badgeScale,
        ringFill: ring.background,
        ringWash: wash,
        change.map { change in
          Circle()
            .fill(theme.color(for: change))
            .frame(width: badgeDiameter, height: badgeDiameter)
        },
      )
      .accessibilityHidden(true)
  }
}
