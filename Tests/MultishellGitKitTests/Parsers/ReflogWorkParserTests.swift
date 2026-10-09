import Testing

@testable import MultishellGitKit

@Suite
struct ReflogWorkParserTests {
  private let firstSHA = "a621d32e17f5d6e0834f751f59a909aa98abe902"
  private let secondSHA = "7a5b0c2c63a767f840f4fdac70999f0400b9a3c6"
  private let thirdSHA = "e4edd1eb5a49409362ada68b85768f06f348920b"

  /// The messages git itself writes, each line `%H %gs`: what `worktree add
  /// -b`, a fast-forward pull, a commit, an amend, a rebase and a reset leave.
  @Test func aReflogSaysWhetherWorkWasEverMadeOnTheBranch() {
    #expect(!ReflogWorkParser.parse("\(firstSHA) branch: Created from main\n"))
    #expect(
      !ReflogWorkParser.parse(
        """
        \(secondSHA) merge origin/main: Fast-forward
        \(firstSHA) branch: Created from main
        """
      ),
      "a worktree cut before the trunk moved, brought up to date",
    )
    #expect(
      !ReflogWorkParser.parse(
        """
        \(secondSHA) pull -q --rebase origin main: Fast-forward
        \(firstSHA) branch: Created from main
        """
      ),
      "the command the user typed is in the message, so only the end is read",
    )
    #expect(
      !ReflogWorkParser.parse(
        """
        \(secondSHA) reset: moving to origin/main
        \(firstSHA) branch: Created from main
        """
      )
    )
    #expect(!ReflogWorkParser.parse(""))

    #expect(
      ReflogWorkParser.parse(
        """
        \(secondSHA) commit: my work
        \(firstSHA) branch: Created from main
        """
      )
    )
    #expect(ReflogWorkParser.parse("\(secondSHA) commit (amend): my work, amended\n"))
    #expect(
      ReflogWorkParser.parse(
        "\(thirdSHA) pull --rebase origin main (finish): refs/heads/feat onto \(secondSHA)\n"
      ),
      "the branch came to rest past the commit it was rebased onto: commits of its own",
    )
    #expect(
      ReflogWorkParser.parse("\(secondSHA) merge origin/main: Merge made by the 'ort' strategy.\n"),
      "a merge commit is a commit of the branch's own",
    )
    #expect(
      ReflogWorkParser.parse("\(secondSHA) something a later git writes: whatever it says\n"),
      "unlisted reads as work, which is what counting entries assumed of every entry",
    )
    #expect(
      ReflogWorkParser.parse("\(secondSHA) commit: Fast-forward\n"),
      "the detail is only read for a merge or a pull, so a subject cannot pose as one",
    )

    // What a fetch writes straight into a local branch, and what a clone
    // leaves on the branch it checked out: someone else's commits, arriving.
    #expect(!ReflogWorkParser.parse("\(secondSHA) fetch -q origin main:feat: storing head\n"))
    #expect(!ReflogWorkParser.parse("\(secondSHA) fetch origin main:feat: fast-forward\n"))
    #expect(!ReflogWorkParser.parse("\(firstSHA) clone: from /tmp/origin.git\n"))
  }

  /// A rebase that replayed nothing writes the same `(finish)` as one that
  /// did; where the branch came to rest, on the target or past it, tells them apart.
  @Test func aRebaseThatReplayedNothingIsAnArrival() {
    #expect(
      !ReflogWorkParser.parse(
        """
        \(secondSHA) rebase (finish): refs/heads/feat onto \(secondSHA)
        \(firstSHA) branch: Created from main
        """
      )
    )
    #expect(
      ReflogWorkParser.parse(
        """
        \(thirdSHA) rebase (finish): refs/heads/feat onto \(secondSHA)
        \(secondSHA) commit: own
        \(firstSHA) branch: Created from main
        """
      )
    )
    #expect(
      !ReflogWorkParser.parse(
        "\(secondSHA) rebase -i (finish): refs/heads/feat onto \(secondSHA)\n"
      ),
      "an interactive rebase names itself differently and finishes the same way",
    )
    #expect(
      !ReflogWorkParser.parse("\(secondSHA) rebase finished: refs/heads/feat onto \(secondSHA)\n"),
      "the wording before git 2.26",
    )
    #expect(
      ReflogWorkParser.parse("\(secondSHA) rebase (finish): refs/heads/feat onto\n"),
      "a finish naming no commit is read as work, the safe side",
    )
    #expect(
      ReflogWorkParser.parse(
        "\(secondSHA) rebase (finish): refs/heads/feat onto \(secondSHA.prefix(7))\n"
      ),
      "git writes the whole id, so a short one is not trusted to be it",
    )
    #expect(
      ReflogWorkParser.parse("\(secondSHA) rebase (start): checkout main\n"),
      "only a finish is judged by where it landed",
    )
    #expect(
      !ReflogWorkParser.parse("\(secondSHA) merge finished: Fast-forward\n"),
      "a branch named `finished` merged in still reads by the merge rule",
    )
  }
}
