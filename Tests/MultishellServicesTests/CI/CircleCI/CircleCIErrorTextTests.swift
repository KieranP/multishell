import Testing

@testable import MultishellServices

@Suite
struct CircleCIErrorTextTests {
  @Test func aProjectCircleCIDoesNotKnowIsNotHostedThere() {
    #expect(CircleCIErrorText.failure(from: CircleCIFixtures.projectNotFound) == .notHosted)
  }

  @Test func anAuthenticationCodeIsLoggedOut() {
    let stderr =
      #"{"error":true,"code":"auth.unauthorized","message":"Not logged in","exit_code":4}"#
    #expect(CircleCIErrorText.failure(from: stderr) == .loggedOut)
  }

  @Test func anyOtherErrorIsPassedOnByItsMessage() {
    let stderr =
      #"{"error":true,"code":"api.error","message":"Pipeline 401 was not found","exit_code":5}"#
    #expect(CircleCIErrorText.failure(from: stderr) == .failed("Pipeline 401 was not found"))
  }

  @Test func plainTextIsReadByItsFirstLine() {
    #expect(CircleCIErrorText.failure(from: "Error: boom\nmore") == .failed("Error: boom"))
  }
}
