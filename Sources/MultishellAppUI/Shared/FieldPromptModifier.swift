import SwiftUI

/// The theme's prompt over an empty field, and its accessibility label: AppKit
/// draws a field's own prompt in the system's grey.
struct FieldPromptModifier: ViewModifier {
  let prompt: String
  let isShown: Bool
  let color: Color

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .leading) {
        if isShown {
          Text(prompt)
            .foregroundStyle(color)
            .lineLimit(1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
      .accessibilityLabel(prompt)
  }
}
