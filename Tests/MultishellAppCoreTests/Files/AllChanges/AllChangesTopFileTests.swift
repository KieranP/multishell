import Testing

@testable import MultishellAppCore

@Suite
struct AllChangesTopFileTests {
  @Test func theNextFilesHeaderPushesTheStickyCopyUpByHowFarItReachesIntoIt() {
    let top = AllChangesTopFile(
      path: "a.swift",
      headerBarTop: 100,
      nextHeaderBarTop: 520,
      scrolledTo: 500,
      barHeight: 30,
    )

    #expect(top.isHeaderScrolledPast)
    #expect(top.pushedUp == 10)
  }

  @Test func aNextHeaderBelowTheStickyCopyLeavesItInPlace() {
    let top = AllChangesTopFile(
      path: "a.swift",
      headerBarTop: 100,
      nextHeaderBarTop: 900,
      scrolledTo: 500,
      barHeight: 30,
    )

    #expect(top.pushedUp == 0)
  }

  @Test func aHeaderNotYetScrolledPastShowsNoStickyCopyToPush() {
    let top = AllChangesTopFile(
      path: "a.swift",
      headerBarTop: 520,
      nextHeaderBarTop: 540,
      scrolledTo: 500,
      barHeight: 30,
    )

    #expect(!top.isHeaderScrolledPast)
    #expect(top.pushedUp == 0)
  }
}
