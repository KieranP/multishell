import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestCheckWordingTests {
  @Test func aCheckIsNamedAfterItsWorkflowWhereItHasOne() {
    #expect(PullRequestCheck.sample(name: "build", workflow: "CI").displayName == "CI / build")
    #expect(PullRequestCheck.sample(name: "danger", workflow: nil).displayName == "danger")
  }
}
