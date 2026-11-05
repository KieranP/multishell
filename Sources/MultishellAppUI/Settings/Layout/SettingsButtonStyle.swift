import SwiftUI

/// A settings page's text button: the mockup's white face, 12 pt, red for a
/// destructive one.
struct SettingsButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    SettingsButtonFace(
      label: configuration.label,
      isDestructive: configuration.role == .destructive,
      isPressed: configuration.isPressed,
    )
  }
}
