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

  @Test func onlyTheMissingGitAlertSaysGitIsMissing() {
    #expect(PresentedError(GitUnavailable()).saysGitIsMissing)
    #expect(!PresentedError(InvalidBranchName("x")).saysGitIsMissing)
    #expect(!PresentedError(title: "git not found", message: "").saysGitIsMissing)
  }
}
