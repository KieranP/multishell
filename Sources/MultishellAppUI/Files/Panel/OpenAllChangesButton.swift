import MultishellAppCore
import MultishellCore
import SwiftUI

/// Beside the Changes page's filter: the worktree's All changes tab, made or
/// turned to; see Docs/design/files/all-changes-tab.md.
struct OpenAllChangesButton: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    PlainGlyphButton(help: t("files-panel.open-all-changes")) {
      model.openAllChangesTab(in: worktreeID)
    } glyph: {
      Image(systemName: AllChangesGlyph.symbolName)
        .font(metrics.font(size: metrics.glyph))
        .foregroundStyle(theme.filesPanel.textSecondary)
        .accessibilityHidden(true)
        .frame(width: metrics.filterWellHeight, height: metrics.filterWellHeight)
        .background(
          theme.filesPanel.fill,
          in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
        )
    }
  }
}
