import Foundation
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeGitBranchesTests {
  @Test func aBranchHeldEveryTipItWasMovedThroughThoughResetAwayFromThem() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let start = try await fixture.tip(of: "main")
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    let left = try await fixture.tip(of: "feat")
    _ = try await fixture.runner.run(["reset", "-q", "--hard", start], in: fixture.project.path)

    let held = try await WorktreeGit(runner: fixture.runner)
      .tipsHeld(byBranch: "feat", in: fixture.project)

    #expect(held == [start, left])
  }

  @Test func aBranchGitKeepsNoReflogForHeldNothing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "feat"], in: fixture.project.path)
    try FileManager.default.removeItem(
      at: fixture.project.path.appendingPathComponent(".git/logs/refs/heads/feat")
    )

    let held = try await WorktreeGit(runner: fixture.runner)
      .tipsHeld(byBranch: "feat", in: fixture.project)

    #expect(held.isEmpty)
  }

  @Test func aBranchThatIsNotThereFailsTheRead() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    await #expect(throws: (any Error).self) {
      try await WorktreeGit(runner: fixture.runner)
        .tipsHeld(byBranch: "missing", in: fixture.project)
    }
  }
}
