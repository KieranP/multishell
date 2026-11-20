import MultishellAppCore
import MultishellCore
import SwiftUI

/// The All changes tab's bar: its title, how many files and lines changed,
/// the arrows stepping across files, and the switches every file tab has.
struct AllChangesBar: View {
  let model: AppModel
  let tab: AllChangesTab
  let document: AllChangesDocument?
  let theme: Theme

  var body: some View {
    let palette = theme.fileTab
    HStack(spacing: 6) {
      Text(model.title(of: tab))
        .fontWeight(.semibold)
        .foregroundStyle(palette.text)
        .lineLimit(1)
      if let document {
        Text(AllChangesText.fileCount(document.sections.count))
          .foregroundStyle(palette.textTertiary)
          .lineLimit(1)
        if !document.lineCounts.isEmpty {
          FileLineCountsText(
            counts: document.lineCounts,
            theme: theme,
            size: model.metrics.caption,
            showsZeroSides: false,
          )
        }
      }
      Spacer(minLength: 8)
      if document?.hasChanges == true {
        ChangeStepButtons(model: model, tabID: tab.id, palette: palette)
      }
      if model.offersChangeScopeSwitch(in: tab.worktreeID) {
        ChangeScopeSwitch(model: model, palette: palette)
      }
      FileTabLayoutSwitch(
        model: model,
        selection: FileTabLayoutSwitch.allChangesSelection(in: model),
        palette: palette,
      )
      if document?.sections.isEmpty == false {
        collapseEveryFileButton(palette: palette)
      }
    }
    .font(model.metrics.font(size: model.metrics.secondary))
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: UIMetrics.fileTabBarHeight)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    .clipped()
    .background(palette.background)
    .hairline(.bottom, palette)
  }

  private func collapseEveryFileButton(palette: AreaPalette) -> some View {
    let expands = model.isEveryAllChangesFileCollapsed(in: tab.id)
    return AllChangesGlyphButton(
      help: expands ? t("all-changes.expand-all") : t("all-changes.collapse-all"),
      palette: palette,
    ) {
      model.toggleEveryAllChangesFileCollapsed(in: tab.id)
    } glyph: {
      AllChangesStrokedGlyph(
        outline: ChevronPairShape(pointsInward: !expands),
        metrics: model.metrics,
      )
    }
  }
}
