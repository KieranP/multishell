import Testing

@testable import MultishellAppCore

@Suite
struct PullRequestMenuItemTests {
  @Test func onlyACreateWhileItPushesIsGreyedOut() {
    #expect(PullRequestMenuItem.create(isPublishing: true).isEnabled == false)
    #expect(PullRequestMenuItem.create(isPublishing: false).isEnabled)
    #expect(PullRequestMenuItem.open(number: 9).isEnabled)
  }
}
