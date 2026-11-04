import MultishellAppCore
import MultishellCore
import SwiftUI

/// A button under a detail placeholder, drawn in the theme on the area's block
/// colour and edged in its border rather than AppKit's grey, lit under the pointer.
struct PlaceholderButton<Icon: View>: View {
  private static var height: Double { 28 }
  private static var cornerRadius: Double { 7 }
  private static var textSize: Double { 13 }
  private static var iconGap: Double { 7 }

  let title: String
  let theme: Theme
  /// For the UI font's family; the placeholder's sizes are its own.
  let metrics: UIMetrics
  let action: () -> Void
  /// Given the title's colour, full text while lit under the pointer, and its size;
  /// a mark with a colour of its own keeps it.
  @ViewBuilder let icon: (_ tint: Color, _ size: Double) -> Icon

  @State private var isHovered = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let isLit = GlyphButtonLight.isLit(isHovered: isHovered, isEnabled: isEnabled)
    let tint = isLit ? theme.detail.text : theme.detail.textSecondary
    // Unlit by its click, as an alert the click can raise hides the pointer's exit.
    return Button {
      isHovered = false
      action()
    } label: {
      HStack(spacing: Self.iconGap) {
        icon(tint, Self.textSize).accessibilityHidden(true)
        Text(title).lineLimit(1)
      }
      .font(metrics.font(size: Self.textSize))
      .foregroundStyle(tint)
      .padding(.horizontal, 12)
      .frame(height: Self.height)
      .background(
        theme.color(.blockBackground, in: .detail),
        in: RoundedRectangle(cornerRadius: Self.cornerRadius),
      )
      // Its edge, as the block alone stands barely off the ground in several themes.
      .overlay {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
          .strokeBorder(theme.detail.border, lineWidth: UIMetrics.hairlineThickness)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .tracksHover($isHovered)
    .accessibilityLabel(title)
  }
}
