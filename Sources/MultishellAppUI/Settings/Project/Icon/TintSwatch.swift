import MultishellCore
import SwiftUI

/// One of the project tints: a disc in its colour, an x on the one for none,
/// ringed where it is the project's.
struct TintSwatch: View {
  let slot: Int?
  let color: Color
  let isSelected: Bool
  let pick: () -> Void

  private var name: String { slot.map { Theme.ansiSlotNames[$0] } ?? t("project.no-tint") }

  var body: some View {
    PlainGlyphButton(help: name, action: pick) {
      ZStack {
        // Outlined, or the theme's white vanishes on a light page and its
        // black on a dark one.
        Circle().fill(color).strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
          .frame(width: 14, height: 14)
        if slot == nil {
          Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
        }
      }
      .overlay {
        if isSelected { Circle().strokeBorder(Color.primary, lineWidth: 1.5).padding(-2.5) }
      }
      .frame(width: 18, height: 18)
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
