import Testing

@testable import MultishellAppCore

@Suite
struct DiffSideTextTests {
  private static let display = DiffDisplayText(
    [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let a"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "var b"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "let c"),
    ],
    marksStaging: true,
  )

  @Test func eachSidesTextHoldsTheLinesItShows() {
    #expect(DiffSideText(of: Self.display, side: .onDisk).string == "let a\nlet c")
    #expect(DiffSideText(of: Self.display, side: .committed).string == "let a\nvar b")
  }

  @Test func eachLineRangeIsWhereItsRowSitsInTheSidesText() {
    let onDisk = DiffSideText(of: Self.display, side: .onDisk)

    #expect(onDisk.lineRanges == [0..<5, 6..<11])
    #expect(onDisk.displayRows == [0, 2])
  }
}
