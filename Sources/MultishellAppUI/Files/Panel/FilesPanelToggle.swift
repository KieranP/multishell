import MultishellAppCore
import MultishellCore
import SwiftUI

/// Shows or shuts the Files panel, in the header's accent while it is open:
/// on the worktree's header while shut, on the panel's own while open.
struct FilesPanelToggle: View {
  let model: AppModel
  let theme: Theme

  var body: some View {
    PlainGlyphButton(help: t("files-panel.toggle-help")) {
      model.toggleFilesPanel()
    } glyph: {
      HeaderGlyph(symbol: "sidebar.right")
    }
    .foregroundStyle(
      model.showsFilesPanel ? theme.color(.accent, in: .header) : theme.header.textSecondary
    )
    .accessibilityLabel(t("files-panel.toggle"))
    .selectableButtonTraits(isSelected: model.showsFilesPanel)
  }
}
