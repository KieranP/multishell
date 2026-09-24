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

  /// A ref name holds no space, so `* ` and `+ ` are git's decoration, but may hold a
  /// parenthesis, so `(wip)` keeps its badge; only a worktree's own names are looked up.
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

  /// The messages git itself writes, each line `%H %gs`: what `worktree add
  /// -b`, a fast-forward pull, a commit, an amend, a rebase and a reset leave.
  @Test func aReflogSaysWhetherWorkWasEverMadeOnTheBranch() {
    #expect(!ReflogWorkParser.parse("\(a) branch: Created from main\n"))
    #expect(
      !ReflogWorkParser.parse(
        """
        \(b) merge origin/main: Fast-forward
        \(a) branch: Created from main
        """), "a worktree cut before the trunk moved, brought up to date")
    #expect(
      !ReflogWorkParser.parse(
        """
        \(b) pull -q --rebase origin main: Fast-forward
        \(a) branch: Created from main
        """), "the command the user typed is in the message, so only the end is read")
    #expect(
      !ReflogWorkParser.parse(
        """
        \(b) reset: moving to origin/main
        \(a) branch: Created from main
        """))
    #expect(!ReflogWorkParser.parse(""))

    #expect(
      ReflogWorkParser.parse(
        """
        \(b) commit: my work
        \(a) branch: Created from main
        """))
    #expect(ReflogWorkParser.parse("\(b) commit (amend): my work, amended\n"))
    #expect(
      ReflogWorkParser.parse(
        "\(c) pull --rebase origin main (finish): refs/heads/feat onto \(b)\n"),
      "the branch came to rest past the commit it was rebased onto: commits of its own")
    #expect(
      ReflogWorkParser.parse("\(b) merge origin/main: Merge made by the 'ort' strategy.\n"),
      "a merge commit is a commit of the branch's own")
    #expect(
      ReflogWorkParser.parse("\(b) something a later git writes: whatever it says\n"),
      "unlisted reads as work, which is what counting entries assumed of every entry")
    #expect(
      ReflogWorkParser.parse("\(b) commit: Fast-forward\n"),
      "the detail is only read for a merge or a pull, so a subject cannot pose as one")

    // What a fetch writes straight into a local branch, and what a clone
    // leaves on the branch it checked out: someone else's commits, arriving.
    #expect(!ReflogWorkParser.parse("\(b) fetch -q origin main:feat: storing head\n"))
    #expect(!ReflogWorkParser.parse("\(b) fetch origin main:feat: fast-forward\n"))
    #expect(!ReflogWorkParser.parse("\(a) clone: from /tmp/origin.git\n"))
  }

  /// A rebase that replayed nothing writes the same `(finish)` as one that
  /// did; where the branch came to rest, on the target or past it, tells them apart.
  @Test func aRebaseThatReplayedNothingIsAnArrival() {
    #expect(
      !ReflogWorkParser.parse(
        """
        \(b) rebase (finish): refs/heads/feat onto \(b)
        \(a) branch: Created from main
        """))
    #expect(
      ReflogWorkParser.parse(
        """
        \(c) rebase (finish): refs/heads/feat onto \(b)
        \(b) commit: own
        \(a) branch: Created from main
        """))
    #expect(
      !ReflogWorkParser.parse("\(b) rebase -i (finish): refs/heads/feat onto \(b)\n"),
      "an interactive rebase names itself differently and finishes the same way")
    #expect(
      !ReflogWorkParser.parse("\(b) rebase finished: refs/heads/feat onto \(b)\n"),
      "the wording before git 2.26")
    #expect(
      ReflogWorkParser.parse("\(b) rebase (finish): refs/heads/feat onto\n"),
      "a finish naming no commit is read as work, the safe side")
    #expect(
      ReflogWorkParser.parse("\(b) rebase (finish): refs/heads/feat onto \(b.prefix(7))\n"),
      "git writes the whole id, so a short one is not trusted to be it")
    #expect(
      ReflogWorkParser.parse("\(b) rebase (start): checkout main\n"),
      "only a finish is judged by where it landed")
    #expect(
      !ReflogWorkParser.parse("\(b) merge finished: Fast-forward\n"),
      "a branch named `finished` merged in still reads by the merge rule")
  }

  private let a = "a621d32e17f5d6e0834f751f59a909aa98abe902"
  private let b = "7a5b0c2c63a767f840f4fdac70999f0400b9a3c6"
  private let c = "e4edd1eb5a49409362ada68b85768f06f348920b"

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
    #expect(
      resolved
        == DefaultBranch(
          ref: "origin/main", branch: "main", tip: "remote", fullRef: "refs/remotes/origin/main"))

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
