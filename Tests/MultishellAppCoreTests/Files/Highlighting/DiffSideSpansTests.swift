import Testing

@testable import MultishellAppCore

@Suite
struct DiffSideSpansTests {
  private static let display = DiffDisplayText([
    DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let a"),
    DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "var b"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "let c"),
  ])

  @Test func eachSidesTextHoldsTheLinesItShows() {
    #expect(DiffSideSpans.sideText(of: Self.display, side: .onDisk) == "let a\nlet c")
    #expect(DiffSideSpans.sideText(of: Self.display, side: .committed) == "let a\nvar b")
  }

  @Test func aSidesSpansLandOnTheRowsThatShowItsLines() {
    let onDisk = [HighlightSpan(range: 6..<9, role: .keyword)]
    let committed = [HighlightSpan(range: 6..<9, role: .keyword)]

    #expect(
      DiffSideSpans.mapped(onDisk, from: .onDisk, onto: Self.display).map(\.range) == [12..<15]
    )
    #expect(
      DiffSideSpans.mapped(committed, from: .committed, onto: Self.display).map(\.range) == [6..<9]
    )
  }

  @Test func aSpanAcrossLinesIsSplitAtEachRow() {
    let comment = [HighlightSpan(range: 2..<9, role: .comment)]

    let mapped = DiffSideSpans.mapped(comment, from: .onDisk, onto: Self.display)

    #expect(mapped.map(\.range) == [2..<5, 12..<15])
  }

  @Test func headsSpansLandOnRemovedRowsAloneWhereTheFileOnDiskIsParsedToo() {
    let committed = [
      HighlightSpan(range: 0..<3, role: .keyword), HighlightSpan(range: 6..<9, role: .keyword),
    ]

    #expect(
      DiffSideSpans.mapped(committed, from: .committed, onto: Self.display).map(\.range) == [6..<9]
    )
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
