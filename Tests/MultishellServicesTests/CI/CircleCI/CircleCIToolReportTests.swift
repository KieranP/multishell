import Testing

@testable import MultishellProcess
@testable import MultishellServices

@Suite
struct CircleCIToolReportTests {
  @Test func aLoggedInCliOfVersionOneIsReady() {
    #expect(
      CircleCIToolReport.status(
        versionOutput: "circleci 1.11.0 (cee106974671)\n",
        authMe: .sample(output: "{}"),
      )
        == .ready(version: "1.11.0", account: nil)
    )
  }

  @Test func theCliBeforeOneHasNoRunCommandsAndIsTooOld() {
    #expect(
      CircleCIToolReport.status(versionOutput: "0.1.31425+7ba21d2\n", authMe: .sample())
        == .unsupportedVersion("0.1.31425+7ba21d2")
    )
  }

  @Test func aCliWithNoLoginIsLoggedOut() {
    #expect(
      CircleCIToolReport.status(
        versionOutput: "circleci 1.11.0 (cee106974671)",
        authMe: .sample(error: "Error: not authenticated. Run circleci auth login.", status: 1),
      ) == .loggedOut
    )
  }

  @Test func onlyACLIKnownToBeOlderThanTheRunCommandsIsLeftOut() {
    #expect(CircleCIToolReport.canRead(versionOutput: "circleci 1.11.0 (cee106974671)\n"))
    #expect(!CircleCIToolReport.canRead(versionOutput: "0.1.31425+7ba21d2\n"))
    #expect(CircleCIToolReport.canRead(versionOutput: "nonsense"), "unknown is no verdict")
  }

  @Test func aFailedLoginCheckSaysWhatCircleCISaid() {
    let auth = ProcessOutput.sample(
      error: #"{"error":true,"code":"server.error","message":"Service unavailable","exit_code":1}"#,
      status: 1,
    )
    #expect(
      CircleCIToolReport.status(versionOutput: "circleci 1.11.0 (abc)\n", authMe: auth)
        == .unreadable("Service unavailable")
    )
  }
}
