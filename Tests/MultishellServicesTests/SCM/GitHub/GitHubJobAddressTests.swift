import Foundation
import Testing

@testable import MultishellServices

@Suite
struct GitHubJobAddressTests {
  @Test func anActionsJobLinkNamesItsHostRepositoryAndJob() throws {
    let link = try #require(
      URL(string: "https://git.example.com/me/demo/actions/runs/44418623259/job/135205394571")
    )

    let address = try #require(GitHubJobAddress(link))

    #expect(address.host == "git.example.com")
    #expect(address.logsEndpoint == "repos/me/demo/actions/jobs/135205394571/logs")
  }

  @Test func aLinkOutsideActionsNamesNoJob() throws {
    let circle = try #require(URL(string: "https://app.circleci.com/pipelines/gh/me/demo/12"))
    let run = try #require(URL(string: "https://github.com/me/demo/actions/runs/7"))

    #expect(GitHubJobAddress(circle) == nil)
    #expect(GitHubJobAddress(run) == nil)
  }

  @Test func aJobSegmentInOtherScriptsDigitsNamesNoJob() throws {
    let link = try #require(URL(string: "https://github.com/me/demo/actions/runs/1/job/%C2%BD"))

    #expect(GitHubJobAddress(link) == nil)
  }
}
