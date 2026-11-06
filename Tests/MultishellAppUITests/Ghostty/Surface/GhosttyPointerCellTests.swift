import CoreGraphics
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyPointerCellTests {
  private let cellSize = CGSize(width: 16, height: 32)

  @Test func pointsInsideOneCellShareIt() {
    let first = GhosttyPointerCell(pixel: CGPoint(x: 33, y: 65), cellSize: cellSize)
    let second = GhosttyPointerCell(pixel: CGPoint(x: 47, y: 95), cellSize: cellSize)

    #expect(first == second)
  }

  @Test func crossingACellEdgeIsAnotherCell() {
    let before = GhosttyPointerCell(pixel: CGPoint(x: 47, y: 65), cellSize: cellSize)
    let after = GhosttyPointerCell(pixel: CGPoint(x: 48, y: 65), cellSize: cellSize)

    #expect(before != after)
  }

  @Test func noCellSizeYetIsNoCell() {
    #expect(GhosttyPointerCell(pixel: CGPoint(x: 4, y: 4), cellSize: .zero) == nil)
  }
}
