import Foundation
import Testing

@testable import MultishellServices

@Suite
struct GitHubOpenPullRequestHeadTests {
  @Test func eachHeadReadsAsGhPrintsIt() throws {
    let heads = try GitHubOpenPullRequestHead.heads(from: Data(GitHubFixtures.openHeads.utf8))

    #expect(heads.map(\.number) == [35])
    #expect(heads.map(\.branch) == ["cli-tweaks"])
  }

  @Test func aHeadMissingItsNumberOrBranchCostsItselfAlone() throws {
    let json =
      #"[{"number":1,"headRefName":"a"},{"number":2},{"headRefName":"c"},"#
      + #"{"number":"four","headRefName":"d"},{"number":5,"headRefName":"e"}]"#

    let heads = try GitHubOpenPullRequestHead.heads(from: Data(json.utf8))

    #expect(heads.map(\.number) == [1, 5])
  }

  @Test func outputThatIsNotAJsonArrayFailsTheReadRatherThanListingNone() {
    #expect(throws: ServiceReadFailure.self) {
      try GitHubOpenPullRequestHead.heads(from: Data("Welcome to GitHub CLI!".utf8))
    }
  }
}
