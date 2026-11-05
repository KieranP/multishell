import SwiftUI

extension View {
  /// The white face, hairline and slight drop the mockup gives a pop-up and a button.
  func settingsControlFace() -> some View {
    background(SettingsColors.control, in: .rect(cornerRadius: UIMetrics.settingsControlRadius))
      .overlay {
        RoundedRectangle(cornerRadius: UIMetrics.settingsControlRadius).strokeBorder(
          SettingsColors.controlEdge,
          lineWidth: UIMetrics.hairlineThickness,
        )
      }
      .shadow(color: .black.opacity(0.07), radius: 0.5, y: 1)
  }
}
