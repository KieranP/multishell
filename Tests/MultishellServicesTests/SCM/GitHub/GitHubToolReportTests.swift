import Testing

@testable import MultishellProcess
@testable import MultishellServices

@Suite
struct GitHubToolReportTests {
  private let version =
    "gh version 2.103.2 (2026-10-23)\nhttps://github.com/cli/cli/releases/tag/v2.103.2\n"

  @Test func aLoggedInGhNamesItsVersionAndAccount() {
    let auth = ProcessOutput.sample(
      output:
        "github.com\n  ✓ Logged in to github.com account KieranP (keyring)\n  - Active account: true\n"
    )
    #expect(
      GitHubToolReport.status(versionOutput: version, authStatus: auth)
        == .ready(version: "2.103.2", account: "KieranP")
    )
  }

  @Test func anOlderGhSaysAsAndWritesToStandardError() {
    let auth = ProcessOutput.sample(
      error: "github.com\n  ✓ Logged in to github.com as octocat (oauth_token)\n"
    )
    #expect(
      GitHubToolReport.status(versionOutput: version, authStatus: auth)
        == .ready(version: "2.103.2", account: "octocat")
    )
  }

  @Test func aGhWithNoLoginIsLoggedOut() {
    let auth = ProcessOutput.sample(
      error: "You are not logged into any GitHub hosts. To log in, run: gh auth login\n",
      status: 1,
    )
    #expect(GitHubToolReport.status(versionOutput: version, authStatus: auth) == .loggedOut)
  }

  @Test func aLoginThatFailsForAnotherReasonSaysThatReasonNotTheHost() {
    let auth = ProcessOutput.sample(
      output:
        "github.com\n  X Timeout trying to log in to github.com account KieranP (keyring)\n  - Active account: true\n",
      status: 1,
    )
    #expect(
      GitHubToolReport.status(versionOutput: version, authStatus: auth)
        == .unreadable("Timeout trying to log in to github.com account KieranP (keyring)")
    )
  }

  @Test func aVersionLineOfAnotherShapeIsPassedOn() {
    #expect(
      GitHubToolReport.status(versionOutput: "hub version 2.14.2\n", authStatus: .sample())
        == .unreadable("hub version 2.14.2")
    )
  }

  @Test func oneHostLoggedOutAmongSeveralLeavesTheLoggedInOneReady() {
    let auth = ProcessOutput.sample(
      output: "github.com\n  ✓ Logged in to github.com account KieranP (keyring)\n",
      error:
        "ghe.corp\n  X Failed to log in to ghe.corp\n  - To re-authenticate, run: gh auth login -h ghe.corp\n",
      status: 1,
    )
    #expect(
      GitHubToolReport.status(versionOutput: version, authStatus: auth)
        == .ready(version: "2.103.2", account: "KieranP")
    )
  }
}
