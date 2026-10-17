import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite
struct PresentedErrorTests {
  @Test func aTerminalTheEngineCouldNotStartSaysSoInWords() {
    let presented = PresentedError(TerminalUnavailable())
    #expect(presented.message == "The terminal could not be started.")
  }
}
