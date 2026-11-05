import MultishellAppCore
import SwiftUI

/// The Global column's cell: the value a project follows, opening the All
/// Projects page that sets it, and its source where that is not the global.
struct OverrideGlobalCell: View {
  let model: AppModel
  let column: OverrideGlobalValue

  @State private var isHovered = false

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      if let section = column.settingsSection {
        Button {
          model.showSettings(section, in: .allProjects)
        } label: {
          valueText
            .underline(isHovered)
            .foregroundStyle(isHovered ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .tracksHover($isHovered)
        .help(t("project.open-global", section.title))
      } else {
        valueText.foregroundStyle(.secondary)
      }
      if let note = column.sourceNote {
        Text(note)
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
      }
    }
  }

  private var valueText: some View {
    Text(column.text)
      .font(.system(size: UIMetrics.settingsControlTextSize))
      .lineLimit(2)
      .truncationMode(.middle)
      .multilineTextAlignment(.leading)
  }
}
