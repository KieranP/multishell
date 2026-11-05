import SwiftUI

/// A settings row's menu, drawn as the mockup's white pop-up: the choice
/// shown, chevrons at its right edge.
struct SettingsPopUp<Value: Hashable, Options: View>: View {
  let label: String
  @Binding var selection: Value
  /// The chosen one's words.
  let title: String
  @ViewBuilder let options: () -> Options

  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    Menu {
      Picker(label, selection: $selection, content: options)
        .pickerStyle(.inline)
        .labelsHidden()
    } label: {
      HStack(spacing: 6) {
        Text(title)
          .lineLimit(1)
          .frame(minWidth: UIMetrics.settingsPopUpMinTitleWidth, alignment: .leading)
        Image(systemName: "chevron.up.chevron.down")
          .accessibilityHidden(true)
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(SettingsColors.secondaryText)
      }
      .foregroundStyle(
        isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(SettingsColors.faintText)
      )
      .padding(.leading, 9)
      .padding(.trailing, 8)
      .padding(.vertical, UIMetrics.settingsControlVerticalInset)
      .settingsControlFace()
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .accessibilityLabel(label)
    .accessibilityValue(title)
  }
}
