import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeGitTrackedFilesTests {
  @Test func everyTrackedPathIsListedAndOneASparseCheckoutLeavesOutIsMarked() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("two folders", files: ["kept/a.txt": "a\n", "left/b.txt": "b\n"])
    _ = try await fixture.runner.run(["sparse-checkout", "set", "kept"], in: fixture.project.path)

    let tracked = try #require(
      await WorktreeGit(runner: fixture.runner).trackedFiles(in: fixture.project.path)
    )

    #expect(tracked.paths.contains("kept/a.txt") && tracked.paths.contains("left/b.txt"))
    #expect(tracked.notCheckedOutPaths == ["left/b.txt"])
    #expect(!tracked.isCapped)
  }
}
