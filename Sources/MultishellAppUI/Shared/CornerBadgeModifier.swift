import SwiftUI

/// A badge on a glyph's lower right corner, ringed in what it sits on so it
/// reads as a gap rather than a second ring of colour. See agents.md.
struct CornerBadgeModifier<Badge: View>: ViewModifier {
  let glyphSize: Double
  let ringFill: Color
  /// `nil` draws nothing, the glyph keeping its whole shape.
  let badge: Badge?

  func body(content: Content) -> some View {
    content.overlay(alignment: .bottomTrailing) {
      if let badge {
        badge
          .padding(1.2)
          .background(ringFill, in: Circle())
          // Pushed out to the corner, so what it covers is the mark's edge
          // rather than the middle that carries the shape.
          .offset(x: glyphSize * 0.26, y: glyphSize * 0.2)
      }
    }
  }
}
