import SwiftUI

/// A card of actions under a heading naming the columns, as `OverrideTable`
/// heads a project's settings.
struct ActionTable<Rows: View>: View {
  let title: String
  @ViewBuilder let rows: () -> Rows

  var body: some View {
    SettingsGroup {
      ActionColumns {
        Text(title)
      } command: {
        Text(t("actions.column-command"))
      } keys: {
        Text(t("actions.column-keys"))
      }
      .settingsColumnHeadings()
      rows()
    }
  }
}
