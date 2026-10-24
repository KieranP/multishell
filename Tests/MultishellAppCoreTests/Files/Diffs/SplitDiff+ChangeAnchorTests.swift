import Testing

@testable import MultishellAppCore

@Suite
struct SplitDiffChangeAnchorTests {
  private static let rows = FileTabRows(
    lines: [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "old b"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "new b"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "c"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 4, text: "d"),
      DiffLine(kind: .context, oldNumber: 4, newNumber: 5, text: "e"),
    ],
    marksStaging: true,
  )

  @Test func aSplitHoldsAChangeByTheLineUnifiedWould() throws {
    let split = try #require(Self.rows.split)

    #expect(split.anchor(ofChangeAt: 1..<2) == Self.rows.displayText.anchor(ofChangeAt: 1..<3))
  }

  @Test func aUnifiedAnchorWhoseNumbersMovedIsFoundInSplitByItsRemovedLine() throws {
    let split = try #require(Self.rows.split)
    let moved = ChangeAnchor(
      committedDigest: 0,
      committedLineAbove: 40,
      committedLineBelow: 41,
      textAbove: "a",
      lineText: "old b",
    )

    #expect(split.change(at: moved) == 1..<2)
  }

  @Test func aRemovalHeldInUnifiedIsFoundInSplitThoughTheRightSideShowsOnlyPadding() throws {
    let removal = FileTabRows(
      lines: [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
        DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "gone b"),
        DiffLine(kind: .context, oldNumber: 3, newNumber: 2, text: "c"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "d"),
      ],
      marksStaging: true,
    )
    let split = try #require(removal.split)
    let anchor = try #require(removal.displayText.anchor(ofChangeAt: 1..<2))

    let rows = try #require(split.change(at: anchor))

    #expect(split.onDisk.lines[rows.lowerBound].kind == .padding)
    #expect(rows == 1..<2)
  }

  @Test func aBraceRemovedOnTheLeftIsHeldByTheWordyLineAddedOnTheRight() throws {
    func rows(committingAbove committed: Int) -> FileTabRows {
      var lines = DiffLine.committedAbove(committed)
      lines += [
        DiffLine(kind: .context, oldNumber: committed + 1, newNumber: nil, text: "a"),
        DiffLine(kind: .removed, oldNumber: committed + 2, newNumber: nil, text: "}"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "return foo(bar)"),
        DiffLine(kind: .context, oldNumber: committed + 3, newNumber: nil, text: "c"),
      ]
      return FileTabRows(lines: lines, marksStaging: true)
    }
    let anchor = try #require(rows(committingAbove: 0).split?.anchor(ofChangeAt: 1..<2))

    #expect(try #require(rows(committingAbove: 3).split).change(at: anchor) == 4..<5)
  }

  @Test func anAdditionAtTheEndKeepsItsBoxInSplitOnceTheLastLineIsRemovedToo() throws {
    func rows(removingTen: Bool) -> FileTabRows {
      FileTabRows(
        lines: (1...9).map { (line: Int) in
          DiffLine(kind: .context, oldNumber: line, newNumber: line, text: "\(line)")
        }
          + [
            DiffLine(
              kind: removingTen ? .removed : .context,
              oldNumber: 10,
              newNumber: nil,
              text: "10",
            ),
            DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "x"),
          ],
        marksStaging: true,
      )
    }
    let anchor = try #require(rows(removingTen: false).displayText.anchor(ofChangeAt: 10..<11))
    let edited = rows(removingTen: true)

    #expect(edited.displayText.change(at: anchor) == 9..<11)
    #expect(try #require(edited.split).change(at: anchor) == 9..<10)
  }

  @Test func eitherSplitSideSeesTheSameHEADAsUnified() throws {
    let split = try #require(Self.rows.split)
    let anchor = try #require(Self.rows.displayText.anchor(ofChangeAt: 1..<3))

    #expect(!split.committed.hasCommittedSideMoved(since: anchor))
    #expect(!split.onDisk.hasCommittedSideMoved(since: anchor))
    #expect(
      !SplitDiff(Self.rows.lines, marksStaging: true).committed.hasCommittedSideMoved(since: anchor)
    )
  }

  @Test func anEditedAdditionHeldInSplitIsFoundByItsPlaceInEitherLayout() throws {
    let anchor = try #require(Self.rows.split?.anchor(ofChangeAt: 3..<4))
    let edited = FileTabRows(
      lines: Self.rows.lines.map { line in
        line.text == "d"
          ? DiffLine(kind: .added, oldNumber: nil, newNumber: line.newNumber, text: "d edited")
          : line
      },
      marksStaging: true,
    )

    #expect(try #require(edited.split).change(at: anchor) == 3..<4)
    #expect(edited.displayText.change(at: anchor) == 4..<5)
  }

  @Test func aMovedLineIsFoundInSplitAtTheChangeNearestItsPlaceOnEitherSide() throws {
    var lines: [DiffLine] = []
    var old = 1
    var new = 1
    for row in 0..<100 {
      switch row {
      case 9:
        lines.append(DiffLine(kind: .removed, oldNumber: old, newNumber: nil, text: "foo()"))
        old += 1

      case 79:
        lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: new, text: "foo()"))
        new += 1

      default:
        lines.append(DiffLine(kind: .context, oldNumber: old, newNumber: new, text: "\(row)"))
        old += 1
        new += 1
      }
    }
    let rows = FileTabRows(lines: lines, marksStaging: true)
    let split = try #require(rows.split)
    let anchor = try #require(rows.displayText.anchor(ofChangeAt: 79..<80))

    #expect(split.change(at: anchor) == 79..<80)
  }
}
