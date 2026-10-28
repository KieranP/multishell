import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's Files and Changes pages: the switch, the filter, the list and its
/// footer; see Docs/design/files.md.
struct FileListPage: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    let summary = model.filesPanelSummary(of: worktree.id)
    let rows = model.fileTreeRows(of: worktree.id)
    if model.filesPanelShowsChangeScopeSwitch {
      // The header's palette: the panel's selection is its fill, so a pill would vanish.
      ChangeScopeSwitch(model: model, palette: theme.header, fillsWidth: true)
        .padding(.horizontal, UIMetrics.sidebarListSideInset)
        .padding(.top, 8)
    }
    FilesPanelFilterField(model: model, worktreeID: worktree.id, theme: theme)
    ScrollView {
      LazyVStack(spacing: UIMetrics.sidebarRowSpacing) {
        ForEach(rows) { row in
          FilesPanelRow(
            model: model,
            worktreeID: worktree.id,
            row: row,
            isSelected: model.isShownFile(row, in: worktree.id),
            theme: theme,
          )
        }
      }
      .padding(.horizontal, 6)
      .padding(.bottom, 8)
    }
    PanelFooter(
      text: FilesPanelFooterText.changes(summary),
      palette: theme.filesPanel,
      metrics: model.metrics,
    ) {
      // Both sides, zeroes too, as the badge draws them: a footer changing
      // shape as the index fills would read as broken; see worktrees.md.
      if summary.changedFiles > 0 {
        FileLineCountsText(
          counts: FileLineCounts(insertions: summary.insertions, deletions: summary.deletions),
          theme: theme,
          size: model.metrics.caption,
          showsZeroSides: true,
        )
      }
      if let omissions = FilesPanelFooterText.omissions(summary) {
        Text(omissions)
          .font(model.metrics.font(size: model.metrics.caption))
          .foregroundStyle(theme.filesPanel.textTertiary)
          .lineLimit(1)
          .help(omissions)
      }
    }
  }
}
