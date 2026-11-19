import MultishellAppCore
import SwiftUI

/// Restore Defaults in the Shortcuts page's header, asking once in place
/// before it clears every change.
struct ShortcutsRestoreButton: View {
  let model: AppModel

  var body: some View {
    HStack(spacing: 6) {
      if model.isAskingToRestoreShortcuts {
        Text(t("shortcuts.restore-question"))
          .font(.system(size: UIMetrics.settingsSmallTextSize))
          .foregroundStyle(SettingsColors.secondaryText)
          .lineLimit(1)
        Button(t("action.cancel"), action: model.endShortcutsPageEdit)
        Button(t("shortcuts.restore"), role: .destructive, action: model.restoreDefaultShortcuts)
      } else {
        Button(t("shortcuts.restore-defaults"), action: model.askToRestoreShortcuts)
          .disabled(!model.hasChangedShortcuts)
      }
    }
    .buttonStyle(SettingsButtonStyle())
  }
}
