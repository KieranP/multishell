import Testing

@testable import MultishellAppCore

struct FileLineCountsTests {
  @Test func twoCountsAddSideBySide() {
    let sum =
      FileLineCounts(insertions: 3, deletions: 1) + FileLineCounts(insertions: 2, deletions: 4)

    #expect(sum == FileLineCounts(insertions: 5, deletions: 5))
  }
}
