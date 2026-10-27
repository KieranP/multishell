import SwiftUI

extension View {
  /// An `ExternalLinkButton` floated over the top trailing corner, so its hit
  /// area adds no height and the card's top padding matches its bottom.
  func cornerLink(
    help: String,
    size: Double,
    color: Color,
    action: @escaping () -> Void,
  ) -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .topTrailing) {
        ExternalLinkButton(help: help, size: size, action: action)
          .foregroundStyle(color)
          .offset(x: ExternalLinkButton.hitPadding / 2, y: -ExternalLinkButton.hitPadding / 2)
      }
  }
}
