import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's Files and Git, and the glyph that shuts it, in the title bar's
/// band; see Docs/design/files.md.
struct FilesPanelHeader: View {
  let model: AppModel
  let theme: Theme

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 2) {
        FilesPanelModeTab(
          model: model,
          mode: .files,
          symbol: "doc.on.doc",
          title: t("files-panel.files"),
          theme: theme,
        )
        FilesPanelModeTab(
          model: model,
          mode: .git,
          symbol: "arrow.triangle.branch",
          title: t("files-panel.git"),
          theme: theme,
        )
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(t("files-panel.which"))
      Spacer(minLength: 8)
      FilesPanelToggle(model: model, theme: theme)
    }
    .windowHeader(fill: theme.header.background)
    .hairline(.bottom, theme.header)
  }
}
