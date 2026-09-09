import Foundation
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
      refs/heads/feat\tcd2\trefs/remotes/origin/feat\t[ahead 1]\t\t1700000000
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
    // The date is the sixth field, so every row written before it existed
    // simply has none; the badges never read it.
    #expect(
      byName["refs/heads/feat"]?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(byName["refs/heads/main"]?.committedAt == nil)
  }

  /// A date git could not print, or one from a build that formatted it
  /// differently, costs the date and not the row.
  @Test func aRefWhoseDateIsNotANumberKeepsTheRest() {
    let refs = BranchRefParser.parse("refs/heads/main\tab1\t\t\t\tMon Jan 1 2024\n")
    #expect(refs.count == 1)
    #expect(refs[0].tip == "ab1")
    #expect(refs[0].committedAt == nil)
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
    // Nothing printed is not an answer: `git cherry` skips merge commits, so
    // a branch whose every commit ahead is a merge prints exactly this.
    #expect(!PatchEquivalenceParser.parse(""))
    #expect(!PatchEquivalenceParser.parse("\n  \n"))
  }

  /// The messages git itself writes, taken from a real repository: what
  /// `git worktree add -b`, a `git pull` that fast-forwards, a commit, an
  /// amend, a rebase and a reset leave in a branch's reflog.
  @Test func aReflogSaysWhetherWorkWasEverMadeOnTheBranch() {
    #expect(!ReflogWorkParser.parse("branch: Created from main\n"))
    #expect(
      !ReflogWorkParser.parse(
        """
        merge origin/main: Fast-forward
        branch: Created from main
        """), "a worktree cut before the trunk moved, brought up to date")
    #expect(
      !ReflogWorkParser.parse(
        """
        pull -q --rebase origin main: Fast-forward
        branch: Created from main
        """), "the command the user typed is in the message, so only the end is read")
    #expect(
      !ReflogWorkParser.parse(
        """
        reset: moving to origin/main
        branch: Created from main
        """))
    #expect(!ReflogWorkParser.parse(""))

    #expect(
      ReflogWorkParser.parse(
        """
        commit: my work
        branch: Created from main
        """))
    #expect(ReflogWorkParser.parse("commit (amend): my work, amended\n"))
    #expect(
      ReflogWorkParser.parse(
        "pull --rebase origin main (finish): refs/heads/feat onto d5e54dd\n"),
      "there were commits of its own to rebase")
    #expect(
      ReflogWorkParser.parse("merge origin/main: Merge made by the 'ort' strategy.\n"),
      "a merge commit is a commit of the branch's own")
    #expect(
      ReflogWorkParser.parse("something a later git writes: whatever it says\n"),
      "unlisted reads as work, which is what counting entries assumed of every entry")
    #expect(
      ReflogWorkParser.parse("commit: Fast-forward\n"),
      "the detail is only read for a merge or a pull, so a subject cannot pose as one")

    // What a fetch writes straight into a local branch, and what a clone
    // leaves on the branch it checked out: someone else's commits, arriving.
    #expect(!ReflogWorkParser.parse("fetch -q origin main:feat: storing head\n"))
    #expect(!ReflogWorkParser.parse("fetch origin main:feat: fast-forward\n"))
    #expect(!ReflogWorkParser.parse("clone: from /tmp/origin.git\n"))
  }

  /// `-z`, so a path holding a newline arrives whole rather than quoted.
  @Test func changedPathsAreReadFromTheNulSeparatedList() {
    #expect(ChangedPathParser.parse("a.txt\u{0}dir/b.txt\u{0}") == ["a.txt", "dir/b.txt"])
    #expect(ChangedPathParser.parse("") == [])
    #expect(
      ChangedPathParser.parse("odd\nname.txt\u{0}b.txt\u{0}") == ["odd\nname.txt", "b.txt"],
      "the newline is part of the path, not a separator")
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
