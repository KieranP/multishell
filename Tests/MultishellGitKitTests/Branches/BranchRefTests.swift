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

  @Test func aBranchStartingWithACombiningMarkIsStillLocalOrRemote() {
    let local = BranchRef(fullName: "refs/heads/\u{0301}foo", tip: "a")
    #expect(local.isLocal)
    #expect(local.shortName == "\u{0301}foo")

    let remote = BranchRef(fullName: "refs/remotes/origin/\u{0301}foo", tip: "a")
    #expect(remote.isRemote)
    #expect(remote.shortName == "origin/\u{0301}foo")
    #expect(remote.nameWithoutRemote == "\u{0301}foo")
    #expect(RefName.shortLocal("refs/heads/\u{0301}foo") == "\u{0301}foo")
  }
}
