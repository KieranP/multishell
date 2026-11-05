import SwiftUI

/// What `SettingsButtonStyle` draws, a view of its own to read whether the
/// button is enabled, which a style's body cannot.
struct SettingsButtonFace<Label: View>: View {
  let label: Label
  let isDestructive: Bool
  let isPressed: Bool

  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    label
      .lineLimit(1)
      .fixedSize()
      .font(.system(size: UIMetrics.settingsControlTextSize))
      .foregroundStyle(isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
      .padding(.horizontal, 10)
      .padding(.vertical, UIMetrics.settingsControlVerticalInset)
      .settingsControlFace()
      .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.45)
      .contentShape(.rect)
  }
}
