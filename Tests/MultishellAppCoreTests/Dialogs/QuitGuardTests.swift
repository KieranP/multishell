import Testing

@testable import MultishellAppCore

@Suite
struct QuitGuardTests {
  @Test func workingAgentsAreCountedApartFromShells() {
    #expect(QuitGuard.message(terminals: 1, working: 0).hasPrefix("One terminal"))
    #expect(
      QuitGuard.message(terminals: 3, working: 1)
        == "3 terminals are still open and will be closed. One of them has an agent that is still working."
    )
    #expect(
      QuitGuard.message(terminals: 4, working: 2).hasSuffix(
        "2 of them have agents that are still working."))
  }
}
