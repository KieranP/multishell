import SwiftUI

/// A themed button's face; a view of its own to read whether the button is enabled.
struct ThemedButtonLabel<Label: View>: View {
  private static var horizontalPadding: Double { 8 }
  private static var verticalPadding: Double { 2 }

  let label: Label
  let fill: Color
  let text: Color
  let cornerRadius: Double
  let disabledOpacity: Double

  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    label
      .foregroundStyle(text)
      .padding(.horizontal, Self.horizontalPadding)
      .padding(.vertical, Self.verticalPadding)
      .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
      .contentShape(.rect)
      .opacity(isEnabled ? 1 : disabledOpacity)
  }
}
