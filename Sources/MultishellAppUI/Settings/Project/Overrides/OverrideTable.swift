import SwiftUI

/// A section of a project's settings beside the global values they override,
/// under a heading naming the columns.
struct OverrideTable<Rows: View>: View {
  let title: String
  /// Help behind an (i) beside the title, `nil` for none.
  let info: String?
  let columnTitles: (global: String, override: String)
  @ViewBuilder let rows: () -> Rows

  var body: some View {
    SettingsGroup {
      OverrideColumns {
        if let info { InfoLabel(sectionHeader: title, info: info) } else { Text(title) }
      } global: {
        Text(columnTitles.global)
      } override: {
        Text(columnTitles.override)
      }
      .font(.system(size: UIMetrics.settingsSmallTextSize, weight: .semibold))
      .foregroundStyle(SettingsColors.secondaryText)
      .accessibilityAddTraits(.isHeader)
      rows()
    }
  }

  init(
    _ title: String = "",
    info: String? = nil,
    columnTitles: (global: String, override: String) = (
      t("project.column-global"), t("project.column-override"),
    ),
    @ViewBuilder rows: @escaping () -> Rows,
  ) {
    self.title = title
    self.info = info
    self.columnTitles = columnTitles
    self.rows = rows
  }
}
