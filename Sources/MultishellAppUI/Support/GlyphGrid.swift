import CoreGraphics

/// The design's 16-unit square that the services' glyphs are drawn on, fitted
/// to the shape's rect.
struct GlyphGrid {
  private static let side: Double = 16

  let unit: Double
  private let origin: CGPoint

  init(fitting rect: CGRect) {
    unit = min(rect.width, rect.height) / Self.side
    origin = rect.origin
  }

  func point(_ x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
  }
}
