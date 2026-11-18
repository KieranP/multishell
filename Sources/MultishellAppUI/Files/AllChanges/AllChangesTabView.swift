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
          noChanges
        } else {
          rows(of: document)
        }
      } else if let failure = model.allChangesReadFailure(of: tab) {
        emptyState(failure)
      } else {
        // The first read lists the files at once; until it lands, this.
        ProgressView()
          .controlSize(.small)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .background(theme.fileTab.background)
  }

  private var noChanges: some View {
    emptyState(model.allChangesEmptyText(of: tab)) {
      if model.offersBranchScope(onEmpty: tab) {
        Button(t("all-changes.show-branch")) { model.setChangeScope(.branch) }
          .buttonStyle(ThemedButtonStyle(fill: theme.fileTab.fill, text: theme.fileTab.text))
      }
    }
  }

  private func emptyState<Action: View>(
    _ text: PanelPageEmptyText,
    @ViewBuilder action: @escaping () -> Action = { EmptyView() },
  ) -> some View {
    PanelPageEmptyState(
      text: text,
      palette: theme.fileTab,
      metrics: model.metrics,
      glyph: ChangedDocumentShape(),
      action: action,
    )
    .background(FileTabFocusTarget(model: model, tabID: tab.id))
  }

  private func rows(of document: AllChangesDocument) -> some View {
    let pending = model.pendingReviewCommentCounts(in: tab.worktreeID)
    return documentView(of: document, pendingComments: pending)
      .id(model.fileFont)
      .overlay(alignment: .top) {
        AllChangesStickyHeader(
          model: model,
          tab: tab,
          document: document,
          pendingComments: pending,
          theme: theme,
        )
      }
      // The next file's header pushes the sticky copy up past the rows' top.
      .clipped()
      .overlay(alignment: .topTrailing) {
        if model.findBarTargetIDs.contains(tab.id) {
          FindBar(model: model, targetID: tab.id, theme: theme)
        }
      }
  }

  private func documentView(
    of document: AllChangesDocument,
    pendingComments: [String: Int],
  ) -> some View {
    let find = FindMatchesShown(
      text: model.findText(of: tab.id),
      matches: model.fileFindMatches(of: tab.id),
      selected: model.selectedFileFindMatch(of: tab.id),
      selectionMoves: model.fileFindSelectionMoves(of: tab.id),
    )
    return AllChangesListRepresentable(
      model: model,
      tab: tab,
      document: document,
      theme: theme,
      font: model.fileFont,
      find: find,
      pendingComments: pendingComments,
    )
  }
}
