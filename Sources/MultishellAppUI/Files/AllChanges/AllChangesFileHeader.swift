import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// One file's header, and its sticky copy over the top: chevron, change letter,
/// path, counts, comments to send and the button opening its own tab.
struct AllChangesFileHeader: View, @MainActor Equatable {
  let model: AppModel
  let tabID: AllChangesTab.ID
  let worktreeID: Worktree.ID
  let section: AllChangesSection
  let pendingComments: Int
  let theme: Theme

  /// What sits a shade off the bar's fill: the letter's square and a lit button.
  private var chipFill: Color {
    theme.fileTab.color(ChipOnFill.colorKey(in: .fileTab, of: theme))
  }

  var body: some View {
    let metrics = model.metrics
    let palette = theme.fileTab
    return HStack(spacing: UIMetrics.allChangesHeaderSpacing) {
      AllChangesGlyphButton(
        help: section.isCollapsed ? t("all-changes.expand") : t("all-changes.collapse"),
        palette: palette,
        litFill: chipFill,
      ) {
        model.toggleAllChangesFileCollapsed(section.path, in: tabID)
      } glyph: {
        Image(systemName: section.isCollapsed ? "chevron.right" : "chevron.down")
          .font(metrics.font(size: metrics.small, weight: .semibold))
          .accessibilityHidden(true)
      }
      changeLetter
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
      AllChangesGlyphButton(
        help: t("all-changes.open-file"),
        palette: palette,
        litFill: chipFill,
      ) {
        Task { await model.openFileAsTab(section.path, in: worktreeID) }
      } glyph: {
        AllChangesStrokedGlyph(outline: ExternalLinkShape(), metrics: metrics)
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .padding(.leading, UIMetrics.allChangesHeaderLeadingInset)
    .padding(.trailing, UIMetrics.allChangesHeaderTrailingInset)
    .frame(height: UIMetrics.fileTabBarHeight)
    .frame(maxWidth: .infinity, alignment: .leading)
    // Opaque, so the sticky copy hides the rows it sits over.
    .background(palette.fill)
    .background(palette.background)
    .hairline(.bottom, palette)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(section.path)
  }

  /// On a square, as the mockups drew it.
  private var changeLetter: some View {
    let metrics = model.metrics
    return Text(AllChangesText.letter(section.change.kind))
      .font(metrics.font(size: metrics.badge, weight: .bold))
      .foregroundStyle(theme.color(for: section.change.kind))
      .frame(width: metrics.allChangesLetterSide, height: metrics.allChangesLetterSide)
      .background(chipFill, in: .rect(cornerRadius: UIMetrics.allChangesLetterCornerRadius))
  }

  /// The same file shown the same way, so a list update that moved nothing of it
  /// leaves its hosted header be.
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.model === rhs.model && lhs.tabID == rhs.tabID && lhs.worktreeID == rhs.worktreeID
      && lhs.section == rhs.section && lhs.pendingComments == rhs.pendingComments
      && lhs.theme == rhs.theme
  }

  private func location(palette: AreaPalette) -> some View {
    let folder = section.change.folder
    return HStack(spacing: 0) {
      if !folder.isEmpty {
        Text(folder + "/")
          .foregroundStyle(palette.textTertiary)
          .lineLimit(1)
          .truncationMode(.head)
      }
      Text(section.change.fileName)
        .fontWeight(.semibold)
        .strikethrough(section.change.kind == .deleted)
        .foregroundStyle(palette.text)
        .lineLimit(1)
        .layoutPriority(1)
    }
  }
}
