import MultishellCore
import SwiftUI

/// A review card's box in a file tab, outlined while Review has it selected.
struct ReviewCardFrame: ViewModifier {
  private static var cornerRadius: Double { 8 }

  let theme: Theme
  let isSelected: Bool

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(theme.fileTab.fill, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
          .strokeBorder(
            isSelected ? theme.color(for: .attention, on: theme.fileTab) : theme.fileTab.border,
            lineWidth: isSelected ? 2 : 1,
          )
      }
  }
}
