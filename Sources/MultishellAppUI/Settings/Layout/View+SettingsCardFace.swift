import SwiftUI

extension View {
  /// The white card and hairline the mockup gives a group of rows and the scope card.
  func settingsCardFace(radius: Double) -> some View {
    background(SettingsColors.card, in: .rect(cornerRadius: radius))
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(SettingsColors.rule, lineWidth: UIMetrics.hairlineThickness)
      }
  }
}
