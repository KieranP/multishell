import SwiftUI

/// A card's corner glyph that opens what it shows on the service's site.
struct ExternalLinkButton: View {
  /// What the hit area adds around the glyph, half on each side.
  static let hitPadding: Double = 9

  let help: String
  let size: Double
  let action: () -> Void

  var body: some View {
    PlainGlyphButton(help: help, action: action) {
      ExternalLinkShape()
        .stroke(style: StrokeStyle(lineWidth: size * 1.5 / 16, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
        .frame(width: size + Self.hitPadding, height: size + Self.hitPadding)
        .accessibilityHidden(true)
    }
  }

  /// The trailing room a line beside a floated `cornerLink` keeps clear.
  static func clearance(forSize size: Double) -> Double { size + hitPadding }
}
