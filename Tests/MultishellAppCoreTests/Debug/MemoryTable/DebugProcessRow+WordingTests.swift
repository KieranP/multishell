import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugProcessRowWordingTests {
  @Test func aNarrowRowNamesItsOwnShareOfTheWholeOnlyWhereItStartedSomething() {
    let rows = DebugProcessRow.rows(of: [
      .sample(pid: 10, parentPID: 1, footprint: 1 << 20),
      .sample(pid: 11, parentPID: 10, footprint: 3 << 20),
    ])
    #expect(rows[0].memorySummary.contains(" self of "))
    #expect(!rows[1].memorySummary.contains("self"))
  }

  @Test func theColumnsSayItsOwnMemoryAndTheWholeItStarted() {
    let rows = DebugProcessRow.rows(of: [
      .sample(pid: 10, parentPID: 1, footprint: 1 << 20),
      .sample(pid: 11, parentPID: 10, footprint: 3 << 20),
    ])
    #expect(rows[0].selfMemoryText == DebugValueText.memory(1 << 20))
    #expect(rows[0].totalMemoryText == DebugValueText.memory(4 << 20))
    #expect(rows[1].selfMemoryText == rows[1].totalMemoryText)
  }
}
