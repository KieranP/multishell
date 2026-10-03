import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugProcessGroupTests {
  @Test func aGroupsSelfIsItsTreeTopsOwnMemoryAndItsTotalIsEverythingUnderThem() {
    let group = DebugProcessGroup(processes: [
      .sample(pid: 10, parentPID: 1, footprint: 5),
      .sample(pid: 11, parentPID: 10, footprint: 600),
      .sample(pid: 20, parentPID: 1, footprint: 6),
    ])

    #expect(group.selfMemory == 11, "two panes' shells")
    #expect(group.totalMemory == 611)
    #expect(group.lines.map(\.process.pid) == [10, 11, 20])
  }
}
