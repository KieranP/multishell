import Testing

@testable import MultishellAppCore

@Suite
struct PullRequestMenuItemWordingTests {
  @Test func openNamesThePullRequestAndCreateAsksMore() {
    #expect(PullRequestMenuItem.open(number: 9).title == "Open Pull Request #9")
    #expect(PullRequestMenuItem.create(isPublishing: false).title == "Create Pull Request…")
  }
}
