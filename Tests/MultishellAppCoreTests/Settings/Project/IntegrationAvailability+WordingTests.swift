import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct IntegrationAvailabilityWordingTests {
  @Test func aMissingOrLoggedOutToolNamesTheCommandThatFixesIt() {
    #expect(
      IntegrationAvailability.notInstalled.text(of: .gitHub)
        == "gh is not on your login shell's PATH. Install it with brew install gh."
    )
    #expect(
      IntegrationAvailability.tool(.loggedOut).text(of: .circleCI)
        == "circleci is not logged in. Run circleci auth login in a terminal."
    )
  }

  @Test func aReadyToolSaysItsVersionAndAccountWhereItGaveOne() {
    #expect(
      IntegrationAvailability.tool(.ready(version: "2.0.0", account: "me")).text(of: .gitHub)
        == "gh 2.0.0, logged in as me."
    )
    #expect(
      IntegrationAvailability.tool(.ready(version: "1.0.0", account: nil)).text(of: .circleCI)
        == "circleci 1.0.0, logged in."
    )
  }

  @Test func aToolGitIsMissingForSaysWhyNothingIsRead() {
    #expect(
      IntegrationAvailability.needsGit.text(of: .gitHub)
        == "gh is installed, but nothing is read without git."
    )
  }
}
