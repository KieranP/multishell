import MultishellAppCore
import MultishellCore
import SwiftUI

/// The All changes tab's content: its bar over every changed file's rows, the
/// file at the top's header held over them; see Docs/design/files/all-changes-tab.md.
struct AllChangesTabView: View {
  let model: AppModel
  let tab: AllChangesTab
  let theme: Theme

  var body: some View {
    let document = model.allChangesDocument(of: tab.id)
    VStack(spacing: 0) {
      AllChangesBar(model: model, tab: tab, document: document, theme: theme)
      if let document {
        if document.sections.isEmpty {
          noChanges.background(FileTabFocusTarget(model: model, tabID: tab.id))
        } else {
          rows(of: document)
        }
      } else {
        theme.fileTab.background
      }
    }
    .background(theme.fileTab.background)
  }

  private var noChanges: some View {
    Text(AllChangesText.noChanges(sinceBase: model.allChangesBaseName(of: tab)))
      .font(model.metrics.font(size: model.metrics.secondary))
      .foregroundStyle(theme.fileTab.textTertiary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func rows(of document: AllChangesDocument) -> some View {
    documentView(of: document)
      .id(model.fileFont)
      .overlay(alignment: .top) { stickyHeader(of: document) }
      .overlay(alignment: .topTrailing) {
        if model.findBarTargetIDs.contains(tab.id) {
          FindBar(model: model, targetID: tab.id, theme: theme)
        }
      }
  }

  @ViewBuilder
  private func documentView(of document: AllChangesDocument) -> some View {
    let find = FindMatchesShown(
      text: model.findText(of: tab.id),
      matches: model.fileFindMatches(of: tab.id),
      selected: model.selectedFileFindMatch(of: tab.id),
      selectionMoves: model.fileFindSelectionMoves(of: tab.id),
    )
    if let split = document.split {
      AllChangesSplitDocumentRepresentable(
        model: model,
        tab: tab,
        document: document,
        split: split,
        theme: theme,
        font: model.fileFont,
        find: find,
      )
    } else {
      AllChangesDocumentRepresentable(
        model: model,
        tab: tab,
        document: document,
        theme: theme,
        font: model.fileFont,
        find: find,
      )
    }
  }

  @ViewBuilder
  private func stickyHeader(of document: AllChangesDocument) -> some View {
    if let top = model.allChangesTopFile(of: tab.id), top.isHeaderScrolledPast,
      let index = document.section(at: top.path)
    {
      AllChangesFileHeader(
        model: model,
        tabID: tab.id,
        worktreeID: tab.worktreeID,
        section: document.sections[index],
        pendingComments: model.pendingReviewCommentCounts(in: tab.worktreeID)[top.path] ?? 0,
        showsFileGap: false,
        theme: theme,
      )
      .padding(.horizontal, UIMetrics.allChangesBoxMargin)
    }
  }
}
