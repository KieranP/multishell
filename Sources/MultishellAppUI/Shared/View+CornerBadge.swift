import SwiftUI

extension View {
  func cornerBadge<Badge: View>(
    onGlyphOf size: Double,
    badgeScale: Double,
    ringFill: Color,
    ringWash: Color?,
    _ badge: Badge?,
  ) -> some View {
    modifier(
      CornerBadgeModifier(
        glyphSize: size,
        badgeScale: badgeScale,
        ringFill: ringFill,
        ringWash: ringWash,
        badge: badge,
      )
    )
  }
}
