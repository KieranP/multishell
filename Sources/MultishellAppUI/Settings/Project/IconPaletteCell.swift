import SwiftUI

/// One symbol in `IconPalette`'s grid: filled where it is the project's icon,
/// ringed where the arrow keys are.
struct IconPaletteCell: View {
  let name: String
  let isCurrent: Bool
  let isHighlighted: Bool
  let size: Double
  let pick: () -> Void

  var body: some View {
    Button(action: pick) {
      Image(systemName: name)
        .font(.system(size: 14))
        .foregroundStyle(isCurrent ? Color.white : Color.primary)
        .frame(width: size, height: size)
        .background(isCurrent ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
          if isHighlighted {
            RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor, lineWidth: 2)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(name)
    .accessibilityLabel(name)
  }
}
