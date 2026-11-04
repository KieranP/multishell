import Testing

@testable import MultishellAppCore

@Suite
struct TerminalCountCapsuleTests {
  @Test func aRowWithTerminalsShowsItsCount() {
    #expect(TerminalCountCapsule.showsCount(of: 1))
  }

  @Test func aRowWithNoTerminalsHidesItsCount() {
    #expect(!TerminalCountCapsule.showsCount(of: 0))
  }
}
