import SwiftUI

extension View {
  func cornerBadge<Badge: View>(
    onGlyphOf size: Double,
    ringFill: Color,
    _ badge: Badge?,
  ) -> some View {
    modifier(CornerBadgeModifier(glyphSize: size, ringFill: ringFill, badge: badge))
  }
}
