import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Shortcuts, one part per menu: a card per group of commands, each
/// beside its default keys; Docs/design/shortcuts.md.
struct AppShortcutsPage: View {
  let model: AppModel
  let section: SettingsSection

  var body: some View {
    SettingsForm {
      ForEach(ShortcutGroup.groups(in: section), id: \.self) { group in
        OverrideTable(
          group.title,
          info: group.info,
          columnTitles: (t("shortcuts.column-default"), t("shortcuts.column-yours")),
        ) {
          ForEach(group.commands, id: \.self) { command in
            ShortcutRow(model: model, command: command)
          }
        }
      }
    }
    // Another part, or a closed window, ends a row's recording or question.
    .onDisappear { model.endShortcutsPageEdit() }
  }
}
