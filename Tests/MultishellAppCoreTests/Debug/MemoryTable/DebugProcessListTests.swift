import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugProcessListTests {
  @Test func aListsSelfIsItsTreeTopsOwnMemoryAndItsTotalIsEverythingUnderThem() {
    let list = DebugProcessList(processes: [
      .sample(pid: 10, parentPID: 1, footprint: 5),
      .sample(pid: 11, parentPID: 10, footprint: 600),
      .sample(pid: 20, parentPID: 1, footprint: 6),
    ])

    #expect(list.selfMemory == 11, "two panes' shells")
    #expect(list.totalMemory == 611)
    #expect(list.rows.map(\.process.pid) == [10, 11, 20])
  }
}
