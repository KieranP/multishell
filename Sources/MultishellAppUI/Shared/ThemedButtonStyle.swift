import SwiftUI

/// A button inside a themed area, on the theme's colours: `.bordered` and
/// `.borderedProminent` draw the system's grey and accent.
struct ThemedButtonStyle: ButtonStyle {
  private static var cornerRadius: Double { 5 }
  private static var disabledOpacity: Double { 0.4 }
  private static var pressedOpacity: Double { 0.8 }

  let fill: Color
  let text: Color

  func makeBody(configuration: Configuration) -> some View {
    ThemedButtonLabel(
      label: configuration.label,
      fill: fill.opacity(configuration.isPressed ? Self.pressedOpacity : 1),
      text: text,
      cornerRadius: Self.cornerRadius,
      disabledOpacity: Self.disabledOpacity,
    )
  }
}
