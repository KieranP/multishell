import Foundation
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyInputMethodRectTests {
  private let cell = CGSize(width: 8, height: 16)

  @Test func anEmptyRangeIsACaretAtItsLocationForDictation() {
    let rect = GhosttyInputMethodRect.rect(
      imePoint: CGRect(x: 100, y: 40, width: 24, height: 16),
      range: NSRange(location: 2, length: 0),
      cell: cell)
    #expect(rect == CGRect(x: 116, y: 40, width: 0, height: 16))
  }

  @Test func markedTextKeepsItsWidthWhereLibghosttyPutIt() {
    let rect = GhosttyInputMethodRect.rect(
      imePoint: CGRect(x: 100, y: 40, width: 24, height: 16),
      range: NSRange(location: 0, length: 3),
      cell: cell)
    #expect(rect == CGRect(x: 100, y: 40, width: 24, height: 16))
  }

  @Test func aRangeWithNoLocationKeepsWhereLibghosttyPutIt() {
    let rect = GhosttyInputMethodRect.rect(
      imePoint: CGRect(x: 100, y: 40, width: 24, height: 16),
      range: NSRange(location: NSNotFound, length: 1),
      cell: cell)
    #expect(rect == CGRect(x: 100, y: 40, width: 24, height: 16))
  }

  @Test func itIsNeverShorterThanACell() {
    let rect = GhosttyInputMethodRect.rect(
      imePoint: CGRect(x: 100, y: 40, width: 0, height: 0), range: NSRange(location: 0, length: 0),
      cell: cell)
    #expect(rect.height == 16)
  }
}
