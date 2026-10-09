import SwiftUI

/// One symbol in `IconPalette`'s grid: filled where it is the project's icon,
/// ringed where the arrow keys are.
struct IconPaletteCell: View {
  let symbol: String
  let isSelected: Bool
  let isHighlighted: Bool
  let size: Double
  let pick: () -> Void

  var body: some View {
    PlainGlyphButton(help: symbol, action: pick) {
      Image(systemName: symbol)
        .font(.system(size: 14))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .frame(width: size, height: size)
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
          if isHighlighted {
            RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor, lineWidth: 2)
          }
        }
        .accessibilityHidden(true)
    }
  }
}
