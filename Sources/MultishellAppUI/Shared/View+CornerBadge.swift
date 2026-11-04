import SwiftUI

extension View {
  func cornerBadge<Badge: View>(
    onGlyphOf size: Double,
    ringFill: Color,
    ringWash: Color?,
    _ badge: Badge?,
  ) -> some View {
    modifier(
      CornerBadgeModifier(glyphSize: size, ringFill: ringFill, ringWash: ringWash, badge: badge)
    )
  }
}
