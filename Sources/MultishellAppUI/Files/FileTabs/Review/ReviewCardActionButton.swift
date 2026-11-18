import MultishellAppCore
import MultishellCore
import SwiftUI

/// A comment card's Edit, Delete or Dismiss, lit under the pointer as the
/// app's glyph buttons are.
struct ReviewCardActionButton: View {
  private static let horizontalPadding: Double = 6
  private static let verticalPadding: Double = 2

  let title: String
  let theme: Theme
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Text(title)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .glyphHover(
          isHovered,
          palette: theme.fileTab,
          resting: theme.fileTab.textSecondary,
          // The card is already on the fill.
          litFill: theme.fileTab.color(ChipOnFill.colorKey(in: .fileTab, of: theme)),
        )
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .fixedSize()
    .tracksHover($isHovered)
  }
}
