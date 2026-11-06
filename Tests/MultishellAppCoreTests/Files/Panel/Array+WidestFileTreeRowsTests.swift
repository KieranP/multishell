import Testing

@testable import MultishellAppCore

@Suite
struct ArrayWidestFileTreeRowsTests {
  private func row(
    _ name: String,
    depth: Int = 0,
    parentFolder: String? = nil,
    lineCounts: FileLineCounts? = nil,
  ) -> FileTreeRow {
    FileTreeRow(
      path: name,
      name: name,
      parentFolder: parentFolder,
      depth: depth,
      isFolder: false,
      isExpanded: false,
      holdsChange: false,
      changeKind: nil,
      lineCounts: lineCounts,
      isRepository: false,
      isIgnored: false,
      isOpenable: true,
    )
  }

  @Test func theLongestNameIsPickedFromRowsFarPastTheFirst() {
    let rows = (0..<5_000).map { row("file\($0).txt") } + [row("a-much-longer-file-name.swift")]

    #expect(rows.likeliestWidest(1).map(\.name) == ["a-much-longer-file-name.swift"])
  }

  @Test func depthCountsTowardARowsWidth() {
    let rows = [row("abcdefgh.swift"), row("abcdef.swift", depth: 4)]

    #expect(rows.likeliestWidest(1).map(\.name) == ["abcdef.swift"])
  }

  @Test func aParentFolderAndLineCountsCountTowardARowsWidth() {
    let plain = row("abcdefghijklmnop.swift")
    let filtered = row("a.swift", parentFolder: "Sources/App/Model")
    let counted = row(
      "abcdefghijkl.swift",
      lineCounts: FileLineCounts(insertions: 1200, deletions: 45),
    )

    #expect(Set([plain, filtered].likeliestWidest(1).map(\.name)) == ["a.swift"])
    #expect(Set([plain, counted].likeliestWidest(1).map(\.name)) == ["abcdefghijkl.swift"])
  }

  @Test func fewerRowsThanAskedForAreAllKept() {
    #expect([row("a.txt"), row("b.txt")].likeliestWidest(64).count == 2)
  }
}
