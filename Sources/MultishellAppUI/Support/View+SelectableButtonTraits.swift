import SwiftUI

extension View {
  /// A row or tab read as a button, and as the selected one where it is.
  func selectableButtonTraits(isSelected: Bool) -> some View {
    accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
