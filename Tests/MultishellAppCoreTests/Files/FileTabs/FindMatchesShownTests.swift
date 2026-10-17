import Testing

@testable import MultishellAppCore

@Suite
struct FindMatchesShownTests {
  @Test func aReReadKeepsTheSelectionWhereANewFindTextOrStepMovesIt() {
    let before = FindMatchesShown(
      text: "a",
      matches: [0..<1, 4..<5],
      selected: 1,
      selectionMoves: 2,
    )

    #expect(
      !FindMatchesShown(text: "a", matches: [0..<1, 2..<3, 6..<7], selected: 2, selectionMoves: 2)
        .movesSelection(from: before)
    )
    #expect(
      FindMatchesShown(text: "ab", matches: [0..<2], selected: 0, selectionMoves: 3)
        .movesSelection(from: before)
    )
    #expect(
      FindMatchesShown(text: "a", matches: [0..<1, 4..<5], selected: 1, selectionMoves: 3)
        .movesSelection(from: before)
    )
    #expect(
      FindMatchesShown(text: "a", matches: [0..<1], selected: 0, selectionMoves: 1)
        .movesSelection(from: nil)
    )
  }
}
