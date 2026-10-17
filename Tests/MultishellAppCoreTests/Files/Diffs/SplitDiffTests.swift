import Testing

@testable import MultishellAppCore

@Suite
struct SplitDiffTests {
  private static let lines = [
    DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "keep"),
    DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "old a"),
    DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "old b"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "new a"),
    DiffLine(kind: .context, oldNumber: 4, newNumber: 3, text: "tail"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 4, text: "end"),
  ]

  @Test func eachRunOfRemovedLinesSitsBesideItsAddedOnesTheShorterPadded() {
    let split = SplitDiff(Self.lines)

    #expect(split.committed.lines.map(\.text) == ["keep", "old a", "old b", "tail", ""])
    #expect(split.onDisk.lines.map(\.text) == ["keep", "new a", "", "tail", "end"])
    #expect(
      split.committed.lines.map(\.kind) == [.context, .removed, .removed, .context, .padding]
    )
    #expect(split.onDisk.lines.count == split.committed.lines.count)
  }

  @Test func aSplitSideCopiesPlainTextWithItsPaddingLeftOut() {
    let side = SplitDiff(Self.lines).onDisk

    #expect(side.plainCopy(selections: [0..<side.string.utf16.count]) == "keep\nnew a\ntail\nend")
  }
}
