import SwiftUI

/// A badge on a glyph's lower right corner, ringed in what it sits on so it
/// reads as a gap rather than a second ring of colour. See agents/board-and-pane-rows.md.
struct CornerBadgeModifier<Badge: View>: ViewModifier {
  let glyphSize: Double
  /// The theme's dot scale the badge is drawn at, which moves it out to keep its centre.
  let badgeScale: Double
  let ringFill: Color
  /// A wash laid over `ringFill` where the glyph's ground wears one too.
  let ringWash: Color?
  /// `nil` draws nothing, the glyph keeping its whole shape.
  let badge: Badge?

  func body(content: Content) -> some View {
    content.overlay(alignment: .bottomTrailing) {
      if let badge {
        badge
          .padding(1.2)
          .background(ringWash ?? .clear, in: Circle())
          .background(ringFill, in: Circle())
          .offset(UIMetrics.cornerBadgeOffset(onGlyphOf: glyphSize, badgeScale: badgeScale))
      }
    }
  }
}
