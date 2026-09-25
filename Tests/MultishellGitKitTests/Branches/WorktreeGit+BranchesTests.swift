import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

/// The ref read carries both the sidebar's commit dates and the badges' tips, and a git that
/// cannot give the first must still give the second.
@Suite(.serialized)
struct WorktreeGitBranchesTests {
  @Test func aGitTooOldForTheDateAtomStillAnswersWithTheRest() async throws {
    // Fails any query naming committerdate, as git does for an unknown
    // format atom, and answers the rest.
    let fake = try FakeGit.make(
      """
      case "$*" in
        *committerdate*) echo "fatal: unknown field name: committerdate:unix" >&2; exit 128 ;;
      esac
      printf 'refs/heads/main\\t111\\t\\t\\t\\n'
      """)
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeGit(runner: fake.runner).branchRefs(Project(path: fake.directory)))

    #expect(refs.map(\.fullName) == ["refs/heads/main"], "the badges still have their tips")
    #expect(refs.first?.tip == "111")
    #expect(refs.first?.committedAt == nil, "the order loses its dates, and only those")
  }

  /// The retry is only for a failure: a git that answers the first query is
  /// asked once.
  @Test func aGitThatAnswersIsAskedOnce() async throws {
    let fake = try FakeGit.make(
      #"printf 'refs/heads/main\t111\t\t\t\t1700000000\n'"#, loggingCalls: true)
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeGit(runner: fake.runner).branchRefs(Project(path: fake.directory)))

    #expect(refs.first?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(FakeGit.calls(in: fake.directory).count == 1)
  }
}
