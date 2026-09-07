import MultishellCore
import Testing

@testable import MultishellGitKit

/// The three outputs a merge check reads, and the pure choice of which ref
/// to measure against. No git: fixture text only.
@Suite
struct MergeParserTests {
  @Test func branchRefsCarryTheirTipAndWhetherTheirUpstreamIsGone() {
    let output = """
      refs/heads/main\tab1\trefs/remotes/origin/main\t
      refs/heads/feat\tcd2\trefs/remotes/origin/feat\t[ahead 1]
      refs/heads/squashed\tef3\trefs/remotes/origin/squashed\t[gone]
      refs/heads/local-only\t004\t\t
      refs/remotes/origin/main\tab1\t\t
      refs/remotes/origin/HEAD\tab1\t\t\trefs/remotes/origin/main
      """
    let refs = BranchRefParser.parse(output)
    let byName = Dictionary(uniqueKeysWithValues: refs.map { ($0.fullName, $0) })

    #expect(refs.count == 6)
    #expect(byName[BranchRef.originHead]?.symref == "refs/remotes/origin/main")
    #expect(byName["refs/heads/main"]?.symref == nil)
    #expect(byName["refs/heads/feat"]?.tip == "cd2")
    #expect(byName["refs/heads/feat"]?.isUpstreamGone == false)
    #expect(byName["refs/heads/squashed"]?.isUpstreamGone == true)
    #expect(byName["refs/heads/local-only"]?.upstream == nil)
    #expect(byName["refs/heads/local-only"]?.isUpstreamGone == false)
    #expect(byName["refs/remotes/origin/main"]?.isRemote == true)
  }

  @Test func aRowWithoutANameOrATipIsDroppedAndTheRestSurvive() {
    let refs = BranchRefParser.parse(
      "refs/heads/main\tab1\t\t\r\nnonsense\n\t\tx\t\nrefs/heads/feat\tcd2\t\t\r\n")
    #expect(refs.map(\.fullName) == ["refs/heads/main", "refs/heads/feat"])
    // The \r a Windows-configured checkout appends is not part of the tip.
    #expect(refs[0].tip == "ab1")
  }

  @Test func aRemoteRefNamesTheBranchWithoutItsRemoteAndKeepsItsOwnSlashes() {
    let remote = BranchRef(fullName: "refs/remotes/origin/release/2.0", tip: "a")
    #expect(remote.shortName == "origin/release/2.0")
    #expect(remote.branchName == "release/2.0")

    let local = BranchRef(fullName: "refs/heads/release/2.0", tip: "a")
    #expect(local.shortName == "release/2.0")
    #expect(local.branchName == "release/2.0")
  }

  /// A ref name may hold no space, so `* ` and `+ ` are always git's own
  /// decoration. A parenthesis is legal in one, so `(wip)` is a branch and
  /// keeps its badge; git's detached line is harmless beside it, since only
  /// names a worktree actually has are ever looked up.
  @Test func mergedBranchesDropGitsDecorationButNeverARealBranchName() {
    let merged = MergedBranchParser.parse(
      """
      * main
      + feat/tabs
        chore/deps
        (wip)
        (HEAD detached at ab12345)

      """)
    #expect(merged.isSuperset(of: ["main", "feat/tabs", "chore/deps", "(wip)"]))
    #expect(!merged.contains(""))
  }

  @Test func aBranchIsPatchEquivalentOnlyWhenNoCommitIsStillMissing() {
    #expect(PatchEquivalenceParser.parse("- ab1\n- cd2\n"))
    #expect(!PatchEquivalenceParser.parse("- ab1\n+ cd2\n"))
    #expect(!PatchEquivalenceParser.parse("+ ab1\n"))
    // Nothing to land is the same answer as everything having landed.
    #expect(PatchEquivalenceParser.parse(""))
  }

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
    #expect(DefaultBranch.resolve(from: refs, override: nil)?.ref == "origin/trunk")
  }

  @Test func resolvingTakesTheFirstCandidateTheRepositoryActuallyHas() {
    let refs = [
      BranchRef(fullName: "refs/heads/main", tip: "local"),
      BranchRef(fullName: "refs/remotes/origin/main", tip: "remote"),
    ]
    let resolved = DefaultBranch.resolve(from: refs, override: nil)
    #expect(resolved == DefaultBranch(ref: "origin/main", branch: "main", tip: "remote"))

    // Local only: a repository that has never had a remote.
    let localOnly = DefaultBranch.resolve(from: [refs[0]], override: nil)
    #expect(localOnly?.ref == "main")
  }

  @Test func anOverrideNamingNothingLeavesNoDefaultBranchRatherThanAGuess() {
    let refs = [BranchRef(fullName: "refs/remotes/origin/main", tip: "a")]
    #expect(DefaultBranch.resolve(from: refs, override: "trunk") == nil)
    #expect(DefaultBranch.resolve(from: [], override: nil) == nil)
  }
}
