import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ReviewLineSelectionTests {
  /// context 1, removed old 2 and 3, added new 2, context 3.
  private static let lines = [
    DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
    DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "b"),
    DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "c"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "B"),
    DiffLine(kind: .context, oldNumber: 4, newNumber: 3, text: "d"),
  ]

  @Test func aDragStartingOnRemovedLinesStaysOnTheCommittedSide() {
    let selection = ReviewLineSelection(from: 1, to: 4, in: Self.lines)

    #expect(selection?.side == .committed)
    #expect(selection?.lines == 2...4)
  }

  @Test func aDragStartingOnAddedLinesNumbersByTheFileOnDisk() {
    let selection = ReviewLineSelection(from: 3, to: 4, in: Self.lines)

    #expect(selection?.side == .onDisk)
    #expect(selection?.lines == 2...3)
  }

  @Test func aDragUpFromAnAddedLineIntoRemovedOnesKeepsToTheFileOnDisk() {
    let selection = ReviewLineSelection(from: 3, to: 1, in: Self.lines)

    #expect(selection?.side == .onDisk)
    #expect(selection?.lines == 2...2)
  }

  @Test func aSplitColumnPicksItsOwnSide() {
    let selection = ReviewLineSelection(from: 0, to: 3, in: Self.lines, side: .onDisk)

    #expect(selection?.side == .onDisk)
    #expect(selection?.lines == 1...2)
  }

  @Test func onlyPaddingRowsPickNothing() {
    let padding = [DiffLine.padding, DiffLine.padding]

    #expect(ReviewLineSelection(from: 0, to: 1, in: padding) == nil)
  }

  @Test func unchangedLinesInASplitsLeftColumnNumberByTheFileOnDisk() {
    let selection = ReviewLineSelection(from: 4, to: 4, in: Self.lines, side: .committed)

    #expect(selection?.side == .onDisk)
    #expect(selection?.lines == 3...3)
  }
}
