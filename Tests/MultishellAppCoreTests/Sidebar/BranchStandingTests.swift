import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite
struct BranchStandingTests {
  @Test func aMergedPullRequestTheBranchWentPastStandsInTheBadgesPlaceToo() {
    let services = WorktreeServices(
      upstream: BranchUpstream(remote: "origin", branch: "feat", tip: "tip"),
      localTip: "tip",
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: [.sample(number: 33, state: .merged, headCommit: "older")],
        remotes: [GitRemote(name: "origin", url: "git@github.com:me/demo.git")],
      ),
      ciRuns: nil,
    )
    let standing = BranchStanding(
      mergeState: .merged(.ancestor, into: "origin/main"),
      services: services,
    )

    #expect(!standing.showsMergedBadge(with: nil))
  }
}
