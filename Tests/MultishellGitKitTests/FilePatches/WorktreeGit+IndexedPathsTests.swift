import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeGitIndexedPathsTests {
  @Test func oneReadSaysWhichPathsTheIndexHoldsAndLeavesOutUntrackedOnes() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "hello\n")
    try "new\n".write(
      to: fixture.project.path.appending(path: "new.txt"),
      atomically: true,
      encoding: .utf8,
    )

    let indexed = await fixture.git.indexedPaths(["a.txt", "new.txt"], in: fixture.project.path)

    #expect(indexed == ["a.txt"])
  }
}
