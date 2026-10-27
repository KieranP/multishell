import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The panel's Files, Changes, PR and CI, and the glyph that shuts it, in the
/// title bar's band; see Docs/design/files.md.
struct FilesPanelHeader: View {
  let model: AppModel
  let theme: Theme

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 2) {
        FilesPanelModeTab(model: model, mode: .files, name: t("files-panel.files"), theme: theme) {
          HeaderGlyph(symbol: "doc.on.doc")
        }
        FilesPanelModeTab(
          model: model,
          mode: .changes,
          name: t("files-panel.changes"),
          theme: theme,
        ) {
          HeaderShapeGlyph(shape: ChangedDocumentShape())
        }
        if model.showsPullRequestPanelPage {
          FilesPanelModeTab(
            model: model,
            mode: .pullRequest,
            name: t("files-panel.pull-request"),
            theme: theme,
          ) {
            HeaderShapeGlyph(shape: PullRequestShape(shape: .open))
          }
        }
        if model.showsCIPanelPage {
          FilesPanelModeTab(model: model, mode: .ciRuns, name: t("files-panel.ci"), theme: theme) {
            HeaderShapeGlyph(shape: CIRunShape(status: .passed))
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(t("files-panel.which"))
      Spacer(minLength: 8)
      FilesPanelToggle(model: model, theme: theme)
    }
    .windowHeader(fill: theme.header.background)
    .hairline(.bottom, theme.header)
    // Its tabs' tooltips hang over the page under it.
    .zIndex(1)
  }
}
