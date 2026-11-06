import CoreGraphics

/// The cell a point falls in, in backing pixels from the pane's top left. The
/// padding is left in, putting its edges a few pixels off the text's.
struct GhosttyPointerCell: Equatable {
  let column: Int
  let row: Int

  /// `nil` before libghostty has a cell size.
  init?(pixel: CGPoint, cellSize: CGSize) {
    guard cellSize.width > 0, cellSize.height > 0 else { return nil }
    column = Int((pixel.x / cellSize.width).rounded(.down))
    row = Int((pixel.y / cellSize.height).rounded(.down))
  }
}
