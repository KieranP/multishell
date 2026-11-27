import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitBranchesTests {
  @Test func aRefCarriesItsTipAndCommitDate() async throws {
    let fake = try FakeGit.make(#"printf 'refs/heads/main\t111\t\t\t\t1700000000\n'"#)
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeGit(runner: fake.runner).branchRefs(Project(path: fake.directory))
    )

    #expect(refs.first?.tip == "111")
    #expect(refs.first?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
  }
}
