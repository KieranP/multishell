import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugProcessLineWordingTests {
  @Test func aNarrowRowNamesItsOwnShareOfTheWholeOnlyWhereItStartedSomething() {
    let lines = DebugProcessLine.lines(of: [
      .sample(pid: 10, parentPID: 1, footprint: 1 << 20),
      .sample(pid: 11, parentPID: 10, footprint: 3 << 20),
    ])
    #expect(lines[0].memorySummary.contains(" self of "))
    #expect(!lines[1].memorySummary.contains("self"))
  }
}
