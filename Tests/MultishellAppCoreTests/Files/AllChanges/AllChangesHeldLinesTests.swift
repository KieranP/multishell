import MultishellCore
import Testing

@testable import MultishellAppCore

struct AllChangesHeldLinesTests {
  private static func context(_ number: Int) -> DiffLine {
    DiffLine(kind: .context, oldNumber: number, newNumber: number + 10, text: "")
  }

  @Test func overlappingAndTouchingSpansHoldEveryLineTheyCoverOnTheirOwnSide() {
    let lines = (0...50).map(Self.context)
    let held = AllChangesHeldLines(
      [
        AllChangesLineSpan(side: .onDisk, lines: 20...22),
        AllChangesLineSpan(side: .onDisk, lines: 23...25),
        AllChangesLineSpan(side: .onDisk, lines: 21...24),
        AllChangesLineSpan(side: .committed, lines: 40...40),
      ],
      within: lines,
    )

    let heldNumbers = lines.indices.filter { held.holds(lines[$0]) }

    #expect(heldNumbers == [10, 11, 12, 13, 14, 15, 40])
  }

  @Test func aSpanPastASidesLastLineHoldsThatLastLine() {
    let lines = (0...30).map(Self.context)
    let held = AllChangesHeldLines(
      [AllChangesLineSpan(side: .committed, lines: 38...42)],
      within: lines,
    )

    let heldNumbers = lines.indices.filter { held.holds(lines[$0]) }

    #expect(heldNumbers == [30])
  }

  @Test func aSpanPastTheEndHoldsASplitsLastPairedRowThoughItIsChanged() {
    let lines = [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: ""),
      DiffLine(kind: .added, oldNumber: 2, newNumber: 2, text: ""),
    ]
    let held = AllChangesHeldLines(
      [AllChangesLineSpan(side: .committed, lines: 5...6)],
      within: lines,
    )

    #expect(lines.map(held.holds) == [false, true])
  }
}
