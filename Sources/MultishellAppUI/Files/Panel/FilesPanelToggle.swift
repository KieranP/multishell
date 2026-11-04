import MultishellAppCore
import MultishellCore
import SwiftUI

/// Shows or shuts the Files panel, in the header's accent while it is open:
/// on the worktree's header while shut, on the panel's own while open.
struct FilesPanelToggle: View {
  let model: AppModel
  let theme: Theme

  var body: some View {
    let resting =
      model.showsFilesPanel ? theme.color(.accent, in: .header) : theme.header.textSecondary
    HeaderGlyphButton(
      symbol: "sidebar.right",
      help: t("files-panel.toggle-help"),
      palette: theme.header,
      resting: resting,
      lit: GlyphButtonLight.turnsToTextWhenLit(isOn: model.showsFilesPanel) ? nil : resting,
    ) {
      model.toggleFilesPanel()
    }
    .accessibilityLabel(t("files-panel.toggle"))
    .selectableButtonTraits(isSelected: model.showsFilesPanel)
  }
}
