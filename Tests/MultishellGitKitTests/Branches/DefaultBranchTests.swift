import Testing

@testable import MultishellGitKit

/// The pure choice of which ref a merge check measures against. No git.
@Suite
struct DefaultBranchTests {
  @Test func theRemoteIsPreferredOverALocalBranchOfTheSameName() {
    let refs = DefaultBranch.candidateRefs(
      override: nil, originHead: "refs/remotes/origin/main")
    #expect(refs.first == "refs/remotes/origin/main")
    #expect(refs.contains("refs/heads/main"))
    #expect(
      refs.firstIndex(of: "refs/remotes/origin/main")! < refs.firstIndex(of: "refs/heads/main")!)
  }

  @Test func withoutAnOriginHeadTheUsualNamesAreTriedInOrder() {
    #expect(
      DefaultBranch.candidateRefs(override: nil, originHead: nil) == [
        "refs/remotes/origin/main", "refs/remotes/origin/master",
        "refs/heads/main", "refs/heads/master",
      ])
  }

  @Test func anOverrideIsTriedOnTheRemoteThenLocallyAndNothingFallsBackAfterIt() {
    #expect(
      DefaultBranch.candidateRefs(override: " develop ", originHead: "origin/main") == [
        "refs/remotes/origin/develop", "refs/heads/develop", "refs/remotes/develop",
      ])
    // Typed in full, as the caption shows it.
    #expect(
      DefaultBranch.candidateRefs(override: "upstream/trunk", originHead: nil).contains(
        "refs/remotes/upstream/trunk"))
  }

  @Test func theClonesOwnDefaultIsReadFromTheSymbolicRefInTheSameScan() {
    let refs = [
      BranchRef(fullName: "refs/remotes/origin/main", tip: "a"),
      BranchRef(fullName: "refs/remotes/origin/trunk", tip: "b"),
      BranchRef(
        fullName: BranchRef.originHead, tip: "b", symref: "refs/remotes/origin/trunk"),
    ]
    // origin/HEAD wins over the origin/main guess that follows it.
    #expect(DefaultBranch.resolve(from: refs, override: nil)?.shortName == "origin/trunk")
  }

  @Test func resolvingTakesTheFirstCandidateTheRepositoryActuallyHas() {
    let refs = [
      BranchRef(fullName: "refs/heads/main", tip: "local"),
      BranchRef(fullName: "refs/remotes/origin/main", tip: "remote"),
    ]
    let resolved = DefaultBranch.resolve(from: refs, override: nil)
    #expect(
      resolved
        == DefaultBranch(
          shortName: "origin/main", branchName: "main", tip: "remote",
          fullName: "refs/remotes/origin/main"))

    // Local only: a repository that has never had a remote.
    let localOnly = DefaultBranch.resolve(from: [refs[0]], override: nil)
    #expect(localOnly?.shortName == "main")
  }

  @Test func anOverrideNamingNothingLeavesNoDefaultBranchRatherThanAGuess() {
    let refs = [BranchRef(fullName: "refs/remotes/origin/main", tip: "a")]
    #expect(DefaultBranch.resolve(from: refs, override: "trunk") == nil)
    #expect(DefaultBranch.resolve(from: [], override: nil) == nil)
  }
}
