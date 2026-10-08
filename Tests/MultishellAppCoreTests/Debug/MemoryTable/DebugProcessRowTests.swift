import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugProcessRowTests {
  @Test func eachChildFollowsItsParentOneDeeperWithSiblingsHeaviestFirst() {
    let rows = DebugProcessRow.rows(of: [
      .sample(pid: 11, parentPID: 10, footprint: 50),
      .sample(pid: 10, parentPID: 1, footprint: 5),
      .sample(pid: 12, parentPID: 10, footprint: 600),
      .sample(pid: 13, parentPID: 12, footprint: 90),
    ])

    #expect(rows.map(\.process.pid) == [10, 12, 13, 11])
    #expect(rows.map(\.depth) == [0, 1, 2, 1])
    #expect(rows.map(\.selfMemory) == [5, 600, 90, 50])
    #expect(rows.map(\.totalMemory) == [745, 690, 90, 50], "each with everything under it")
  }

  @Test func twoPanesOfATabAreTwoTreesTheHeavierFirst() {
    let rows = DebugProcessRow.rows(of: [
      .sample(pid: 10, parentPID: 1, footprint: 5),
      .sample(pid: 20, parentPID: 1, footprint: 400),
      .sample(pid: 21, parentPID: 20, footprint: 1),
    ])
    #expect(rows.map(\.process.pid) == [20, 21, 10])
    #expect(rows.map(\.depth) == [0, 1, 0])
  }

  @Test func pidsInALoopAreStillListedOnce() {
    let rows = DebugProcessRow.rows(of: [
      .sample(pid: 10, parentPID: 11), .sample(pid: 11, parentPID: 10),
    ])
    #expect(rows.map(\.process.pid).sorted() == [10, 11])
  }

  @Test func siblingsAreOrderedByWhatTheirWholeTreeHoldsNotTheirOwnFootprint() {
    let rows = DebugProcessRow.rows(of: [
      .sample(pid: 10, parentPID: 1, footprint: 5),
      .sample(pid: 11, parentPID: 10, footprint: 600),
      .sample(pid: 20, parentPID: 1, footprint: 6),
    ])
    #expect(rows.map(\.process.pid) == [10, 11, 20], "a small shell running a large agent")
  }
}
