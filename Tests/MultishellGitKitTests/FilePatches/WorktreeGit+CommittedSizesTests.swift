import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeGitCommittedSizesTests {
  @Test func oneReadGivesEachCommittedFilesSizeAndNoneForAFileTheCommitLacks() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "hello\n")
    try await fixture.commit("nested", file: "docs/b c.txt", content: "hi\n")

    let sizes = await fixture.git.committedSizes(
      of: ["a.txt", "docs/b c.txt", "new.txt"],
      in: fixture.project.path,
      at: "HEAD",
    )

    #expect(sizes == ["a.txt": 6, "docs/b c.txt": 3])
  }
}
