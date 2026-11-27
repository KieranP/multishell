import SwiftUI

/// "Same", reading "Override" under the pointer, for a row with nothing of its own:
/// a project's setting following the global, a command its default, a keyless action.
struct OverrideStartButton: View {
  /// The tooltip and VoiceOver's label, naming the row's setting.
  let help: String
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
    .help(help)
    .accessibilityLabel(help)
  }
}
