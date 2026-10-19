import Testing

@testable import MultishellAppCore

@Suite
struct DiffSideSpansTests {
  private static let display = DiffDisplayText([
    DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let a"),
    DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "var b"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "let c"),
  ])

  private static func side(
    _ side: DiffSide,
    of display: DiffDisplayText = Self.display,
  ) -> DiffSideText {
    DiffSideText(of: display, side: side)
  }

  @Test func aSidesSpansLandOnTheRowsThatShowItsLines() {
    let onDisk = [HighlightSpan(range: 6..<9, role: .keyword)]
    let committed = [HighlightSpan(range: 6..<9, role: .keyword)]

    #expect(
      DiffSideSpans.mapped(onDisk, from: Self.side(.onDisk)).map(\.range) == [12..<15]
    )
    #expect(
      DiffSideSpans.mapped(committed, from: Self.side(.committed)).map(\.range) == [6..<9]
    )
  }

  @Test func aSpanAcrossLinesIsSplitAtEachRow() {
    let comment = [HighlightSpan(range: 2..<9, role: .comment)]

    let mapped = DiffSideSpans.mapped(comment, from: Self.side(.onDisk))

    #expect(mapped.map(\.range) == [2..<5, 12..<15])
  }

  @Test func headsSpansLandOnRemovedRowsAloneWhereTheFileOnDiskIsParsedToo() {
    let committed = [
      HighlightSpan(range: 0..<3, role: .keyword), HighlightSpan(range: 6..<9, role: .keyword),
    ]

    #expect(
      DiffSideSpans.mapped(committed, from: Self.side(.committed)).map(\.range) == [6..<9]
    )
  }

  @Test func headsKeptRangesAreItsRemovedRunsWhereTheFileOnDiskIsParsedToo() {
    let display = DiffDisplayText([
      DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "var a"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "var b"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 1, text: "let c"),
      DiffLine(kind: .removed, oldNumber: 4, newNumber: nil, text: "var d"),
    ])

    #expect(DiffSideSpans.keptRanges(of: Self.side(.committed, of: display)) == [0..<11, 18..<23])
    #expect(DiffSideSpans.keptRanges(of: Self.side(.onDisk, of: display)) == nil)
  }

  @Test func headsKeptRangesLeaveOutABlankRemovedRowOnItsOwn() {
    let display = DiffDisplayText([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let a"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: ""),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 2, text: "let b"),
      DiffLine(kind: .removed, oldNumber: 4, newNumber: nil, text: ""),
      DiffLine(kind: .removed, oldNumber: 5, newNumber: nil, text: "var c"),
    ])

    #expect(DiffSideSpans.keptRanges(of: Self.side(.committed, of: display)) == [13..<19])
  }

  @Test func aSplitsHeadSideKeepsItsWholeText() {
    let left = SplitDiff(Self.display.lines).committed

    #expect(DiffSideSpans.keptRanges(of: Self.side(.committed, of: left)) == nil)
  }

  @Test func headIsParsedOnlyWhereARowShowsItAlone() {
    let unchanged = DiffDisplayText([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let a")
    ])

    #expect(DiffSideSpans.parsedSides(of: unchanged) == [.onDisk])
    #expect(DiffSideSpans.parsedSides(of: Self.display) == [.committed, .onDisk])
    #expect(DiffSideSpans.parsedSides(of: SplitDiff(Self.display.lines).committed) == [.committed])
  }
}
