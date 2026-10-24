import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextSameLineTests {
  @Test func aMatchOnALineSplitsRightSideLacksCarriesToTheNextLineItHas() throws {
    let rows = FileTabRows.replacedBlock(before: 50, removed: 1, added: 1, after: 49)
    let unified = rows.displayText
    let split = try #require(rows.split)
    let removedRow = try #require(unified.lines.firstIndex { $0.kind == .removed })

    let carried = try #require(
      split.onDisk.rangeOnSameLine(unified.range(ofRow: removedRow), from: unified)
    )

    #expect(split.onDisk.row(atOffset: carried.lowerBound) == 50)
  }

  @Test func aMatchOnATrailingLineSplitsRightSideLacksCarriesToTheLastLineItHas() throws {
    let rows = FileTabRows(
      lines: [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "foo"),
        DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "foo"),
        DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "x"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "y"),
        DiffLine(kind: .context, oldNumber: 4, newNumber: 4, text: "bar"),
        DiffLine(kind: .removed, oldNumber: 5, newNumber: nil, text: "foo"),
      ],
      marksStaging: true,
    )
    let unified = rows.displayText
    let split = try #require(rows.split)

    let carried = try #require(
      split.onDisk.rangeOnSameLine(unified.range(ofRow: 5), from: unified)
    )

    #expect(carried.lowerBound == split.onDisk.range(ofRow: 3).upperBound)
  }
}
