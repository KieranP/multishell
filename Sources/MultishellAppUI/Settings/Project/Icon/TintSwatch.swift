import MultishellCore
import SwiftUI

/// One of the project tints: a disc in its colour, checked for none, ringed in
/// the accent where it is the project's.
struct TintSwatch: View {
  let slot: Int?
  /// The slot's colour, `nil` for no tint.
  let color: Color?
  let isSelected: Bool
  let pick: () -> Void

  private var name: String { slot.map { Theme.projectIconSlotNames[$0] } ?? t("project.no-tint") }

  var body: some View {
    PlainGlyphButton(help: name, action: pick) {
      disc
        // Outlined, or the theme's white vanishes on a light page and its
        // black on a dark one.
        .overlay {
          Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: UIMetrics.hairlineThickness)
        }
        .frame(width: UIMetrics.settingsSwatchSide, height: UIMetrics.settingsSwatchSide)
        .overlay {
          if isSelected { Circle().strokeBorder(Color.accentColor, lineWidth: 1.5).padding(-3.5) }
        }
        .frame(width: UIMetrics.settingsSwatchSide + 4, height: UIMetrics.settingsSwatchSide + 4)
    }
    .selectableButtonTraits(isSelected: isSelected)
  }

  /// A checkerboard for no tint, the mockup's mark for none.
  @ViewBuilder private var disc: some View {
    if let color {
      Circle().fill(color)
    } else {
      Canvas { context, size in
        let square = size.width / 4
        for row in 0..<4 {
          for column in 0..<4 where (row + column).isMultiple(of: 2) {
            let cell = CGRect(
              x: Double(column) * square,
              y: Double(row) * square,
              width: square,
              height: square,
            )
            context.fill(Path(cell), with: .color(SettingsColors.faintText))
          }
        }
      }
      .clipShape(.circle)
    }
  }
}
