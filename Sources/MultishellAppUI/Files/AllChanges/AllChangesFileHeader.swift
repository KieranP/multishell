import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// One file's header in the All changes tab, and its sticky copy over the top:
/// the chevron, the change's letter, where it is, its counts, comments to send
/// and the button opening its own tab.
struct AllChangesFileHeader: View {
  let model: AppModel
  let tabID: AllChangesTab.ID
  let worktreeID: Worktree.ID
  let section: AllChangesSection
  let pendingComments: Int
  /// The gap above, which the sticky copy leaves out.
  let showsFileGap: Bool
  let theme: Theme

  var body: some View {
    VStack(spacing: 0) {
      if showsFileGap { theme.fileTab.background.frame(height: UIMetrics.allChangesFileGap) }
      bar
    }
  }

  private var bar: some View {
    let metrics = model.metrics
    let palette = theme.fileTab
    return HStack(spacing: UIMetrics.allChangesHeaderSpacing) {
      PlainGlyphButton(
        help: section.isCollapsed ? t("all-changes.expand") : t("all-changes.collapse")
      ) {
        model.toggleAllChangesFileCollapsed(section.path, in: tabID)
      } glyph: {
        Image(systemName: section.isCollapsed ? "chevron.right" : "chevron.down")
          .font(metrics.font(size: metrics.small, weight: .semibold))
          .foregroundStyle(palette.textSecondary)
          .frame(width: metrics.glyph, height: metrics.glyph)
          .accessibilityHidden(true)
      }
      Text(AllChangesText.letter(section.change.kind))
        .font(.system(size: metrics.caption, weight: .bold, design: .monospaced))
        .foregroundStyle(theme.color(for: section.change.kind))
      location(palette: palette)
      if let counts = section.lineCounts {
        FileLineCountsText(
          counts: counts,
          theme: theme,
          size: metrics.caption,
          showsZeroSides: false,
        )
      }
      if pendingComments > 0 {
        ReviewCountBadge(count: pendingComments, theme: theme, metrics: metrics)
      }
      Spacer(minLength: 0)
      PlainGlyphButton(help: t("all-changes.open-file")) {
        Task { await model.openFileAsTab(section.path, in: worktreeID) }
      } glyph: {
        Image(systemName: "arrow.up.forward.square")
          .font(metrics.font(size: metrics.glyph))
          .foregroundStyle(palette.textSecondary)
          .accessibilityHidden(true)
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .padding(.horizontal, 10)
    .frame(height: UIMetrics.allChangesHeaderBarHeight)
    .frame(maxWidth: .infinity, alignment: .leading)
    // Opaque, so the sticky copy hides the rows it sits over.
    .background(palette.fill)
    .background(palette.background)
    .hairline(.bottom, palette)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(section.path)
  }

  private func location(palette: AreaPalette) -> some View {
    let parts = section.path.split(separator: "/")
    let folder = parts.dropLast().joined(separator: "/")
    return HStack(spacing: 0) {
      if !folder.isEmpty {
        Text(folder + "/")
          .foregroundStyle(palette.textTertiary)
          .lineLimit(1)
          .truncationMode(.head)
      }
      Text(parts.last.map(String.init) ?? section.path)
        .fontWeight(.semibold)
        .strikethrough(section.change.kind == .deleted)
        .foregroundStyle(palette.text)
        .lineLimit(1)
        .layoutPriority(1)
    }
  }
}
