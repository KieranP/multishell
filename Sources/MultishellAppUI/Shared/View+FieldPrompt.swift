import SwiftUI

extension View {
  /// On a `TextField` with an empty title; a font set after this reaches both.
  func fieldPrompt(_ prompt: String, isShown: Bool, color: Color) -> some View {
    modifier(FieldPromptModifier(prompt: prompt, isShown: isShown, color: color))
  }
}
