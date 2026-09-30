import Testing

@testable import MultishellGitKit

@Suite
struct BranchRefTests {
  @Test func aRemoteRefNamesTheBranchWithoutItsRemoteAndKeepsItsOwnSlashes() {
    let remote = BranchRef(fullName: "refs/remotes/origin/release/2.0", tip: "a")
    #expect(remote.shortName == "origin/release/2.0")
    #expect(remote.nameWithoutRemote == "release/2.0")

    let local = BranchRef(fullName: "refs/heads/release/2.0", tip: "a")
    #expect(local.shortName == "release/2.0")
    #expect(local.nameWithoutRemote == "release/2.0")
  }
}
