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
      if model.offersChangeScopeSwitch(for: tab) {
        ChangeScopeSwitch(model: model, palette: palette)
      }
      FileTabLayoutSwitch(
        model: model,
        selection: FileTabLayoutSwitch.selection(in: model, for: tab),
        palette: palette,
      )
    }
    .font(model.metrics.font(size: model.metrics.secondary))
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: UIMetrics.allChangesHeaderBarHeight)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    .clipped()
    .background(palette.background)
    .hairline(.bottom, palette)
  }
}
