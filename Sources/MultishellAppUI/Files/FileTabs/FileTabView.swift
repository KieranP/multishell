import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file tab's content: its bar over the file's rows, or a notice where
/// there are none to show.
struct FileTabView: View {
  let model: AppModel
  let tab: FileTab
  let theme: Theme

  private var fileFont: FileFont {
    FileFont(
      family: model.workspace.appearance.fileFontName,
      size: model.workspace.appearance.fileFontSize,
    )
  }

  var body: some View {
    let reading = model.fileTabReadings[tab.id]
    VStack(spacing: 0) {
      FileTabBar(model: model, tab: tab, reading: reading, theme: theme)
      switch reading?.content {
      case .text(let rows):
        rowsView(of: rows)
          .id(fileFont)
          .overlay(alignment: .topTrailing) {
            if model.findBarTargetIDs.contains(tab.id) {
              FindBar(model: model, targetID: tab.id, theme: theme)
            }
          }

      case .some(let content) where FileTabNoticeText.message(for: content) != nil:
        FileTabNotice(model: model, tab: tab, content: content, theme: theme)

      case .some, nil:
        theme.fileTab.background
      }
    }
    .background(theme.fileTab.background)
  }

  @ViewBuilder
  private func rowsView(of rows: FileTabRows) -> some View {
    let find = FindMatchesShown(
      text: model.findText(of: tab.id),
      matches: model.fileFindMatches(of: tab.id),
      selected: model.selectedFileFindMatch(of: tab.id),
      selectionMoves: model.fileFindSelectionMoves(of: tab.id),
    )
    if let split = model.shownSplit(of: tab) {
      SplitDiffDocumentRepresentable(
        model: model,
        tabID: tab.id,
        path: tab.path,
        split: split,
        theme: theme,
        font: fileFont,
        find: find,
      )
    } else {
      DiffDocumentRepresentable(
        model: model,
        tabID: tab.id,
        path: tab.path,
        text: rows.displayText,
        theme: theme,
        font: fileFont,
        find: find,
      )
    }
  }
}
