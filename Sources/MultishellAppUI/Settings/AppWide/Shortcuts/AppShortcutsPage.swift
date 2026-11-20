import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Shortcuts, one part per menu: a card per group of commands, each
/// beside its default keys, the first card's heading naming the columns for all;
/// Docs/design/shortcuts.md.
struct AppShortcutsPage: View {
  let model: AppModel
  let section: SettingsSection

  var body: some View {
    SettingsForm {
      ForEach(ShortcutGroup.groups(in: section), id: \.self) { group in
        if group.headsItsPart {
          OverrideTable(
            columnTitles: (t("shortcuts.column-default"), t("shortcuts.column-yours"))
          ) {
            rows(of: group)
          }
        } else {
          SettingsGroup { rows(of: group) }
        }
      }
    }
    // Another part, or a closed window, ends a row's recording or question.
    .onDisappear { model.endShortcutsPageEdit() }
  }

  private func rows(of group: ShortcutGroup) -> some View {
    ForEach(group.commands, id: \.self) { command in
      ShortcutRow(model: model, command: command)
    }
  }
}
