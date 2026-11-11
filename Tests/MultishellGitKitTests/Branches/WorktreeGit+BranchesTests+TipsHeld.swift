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

    let held = try await fixture.git
      .tipsHeld(byBranch: "feat", in: fixture.project)

    #expect(held == [start, left])
  }

  @Test func aFileNamedLikeTheBranchsRefDoesNotFailItsReflogReads() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "feat"], in: fixture.project.path)
    let lookalike = fixture.project.path.appendingPathComponent("refs/heads/feat")
    try FileManager.default.createDirectory(
      at: lookalike.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try Data().write(to: lookalike)

    let held = try await fixture.git.tipsHeld(byBranch: "feat", in: fixture.project)
    let madeFrom = try await fixture.git.startPoint(ofBranch: "feat", in: fixture.project)

    #expect(held == [try await fixture.tip(of: "main")])
    #expect(madeFrom == "main")
  }

  @Test func aBranchMadeFromOneStartingWithACombiningMarkKnowsItsStart() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "\u{0301}x"], in: fixture.project.path)
    _ = try await fixture.runner.run(["branch", "y", "\u{0301}x"], in: fixture.project.path)

    let madeFrom = try await fixture.git.startPoint(ofBranch: "y", in: fixture.project)

    #expect(madeFrom == "\u{0301}x")
  }

  @Test func aBranchGitKeepsNoReflogForHeldNothing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "feat"], in: fixture.project.path)
    try FileManager.default.removeItem(
      at: fixture.project.path.appendingPathComponent(".git/logs/refs/heads/feat")
    )

    let held = try await fixture.git
      .tipsHeld(byBranch: "feat", in: fixture.project)

    #expect(held.isEmpty)
  }

  @Test func aBranchThatIsNotThereFailsTheRead() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    await #expect(throws: (any Error).self) {
      try await fixture.git
        .tipsHeld(byBranch: "missing", in: fixture.project)
    }
  }
}
