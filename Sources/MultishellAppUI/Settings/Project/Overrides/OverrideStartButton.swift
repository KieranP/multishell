import SwiftUI

/// The Override column while the project follows: "Same", reading "Override" under
/// the pointer, and starting an override seeded with the value it followed.
struct OverrideStartButton: View {
  /// The setting's row label, for the tooltip and VoiceOver.
  let label: String
  let start: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: start) {
      Text(isHovered ? t("project.override-start") : t("project.override-same"))
        .font(.system(size: UIMetrics.settingsControlTextSize))
        .foregroundStyle(isHovered ? AnyShapeStyle(.tint) : AnyShapeStyle(SettingsColors.faintText))
        .padding(.horizontal, 8)
        .padding(.vertical, UIMetrics.settingsControlVerticalInset)
        .overlay {
          RoundedRectangle(cornerRadius: UIMetrics.settingsControlRadius)
            .strokeBorder(
              isHovered ? AnyShapeStyle(.tint) : AnyShapeStyle(SettingsColors.outline),
              style: StrokeStyle(lineWidth: 1, dash: isHovered ? [] : [3, 3]),
            )
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .tracksHover($isHovered)
    .help(t("project.override-help", label))
    .accessibilityLabel(t("project.override-help", label))
  }
}
