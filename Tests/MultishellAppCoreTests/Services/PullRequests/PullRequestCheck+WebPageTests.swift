import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestCheckWebPageTests {
  @Test func onlyAnHTTPLinkIsAPageToOpen() {
    #expect(
      PullRequestCheck.sample(link: URL(string: "https://github.com/me/demo/actions/runs/1"))
        .webPage != nil
    )
    #expect(PullRequestCheck.sample(link: URL(string: "HTTP://example.com")).webPage != nil)
    #expect(PullRequestCheck.sample(link: URL(string: "file:///etc/passwd")).webPage == nil)
    #expect(PullRequestCheck.sample(link: nil).webPage == nil)
  }
}
