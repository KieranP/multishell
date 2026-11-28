import Testing

@testable import MultishellAppCore

struct FileTabRowsTests {
  @Test func theLastTextOnDiskKeepsALineCutForDisplayWhole() {
    let long = String(repeating: "x", count: 12_000)
    let rows = FileTabRows(
      lines: [DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: long)],
      marksStaging: true,
    )

    #expect(rows.lastTextOnDisk().displayText.uncutText(ofRow: 0) == long)
  }
}
