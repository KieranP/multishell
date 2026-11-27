import Testing

@testable import MultishellAppCore

@Suite
struct ActionRowDropTests {
  @Test func aRowLandsInTheGapThePointerMarks() {
    #expect(ActionRowDrop(row: 2, isAfter: true).destination(movingFrom: 0) == 2)
    #expect(ActionRowDrop(row: 2, isAfter: false).destination(movingFrom: 0) == 1)
    #expect(ActionRowDrop(row: 0, isAfter: false).destination(movingFrom: 2) == 0)
    #expect(ActionRowDrop(row: 0, isAfter: true).destination(movingFrom: 2) == 1)
  }

  @Test func theGapsEitherSideOfTheMovingRowMoveNothing() {
    #expect(ActionRowDrop(row: 1, isAfter: false).destination(movingFrom: 1) == nil)
    #expect(ActionRowDrop(row: 1, isAfter: true).destination(movingFrom: 1) == nil)
    #expect(ActionRowDrop(row: 0, isAfter: true).destination(movingFrom: 1) == nil)
    #expect(ActionRowDrop(row: 2, isAfter: false).destination(movingFrom: 1) == nil)
  }
}
