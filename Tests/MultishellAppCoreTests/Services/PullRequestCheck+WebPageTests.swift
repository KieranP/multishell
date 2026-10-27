import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestCheckWebPageTests {
  private func check(_ link: String?) -> PullRequestCheck {
    PullRequestCheck(
      name: "build",
      workflow: nil,
      status: .passed,
      isRequired: false,
      link: link.flatMap(URL.init(string:)),
    )
  }

  @Test func onlyAnHTTPLinkIsAPageToOpen() {
    #expect(check("https://github.com/me/demo/actions/runs/1").webPage != nil)
    #expect(check("HTTP://example.com").webPage != nil)
    #expect(check("file:///etc/passwd").webPage == nil)
    #expect(check(nil).webPage == nil)
  }
}
