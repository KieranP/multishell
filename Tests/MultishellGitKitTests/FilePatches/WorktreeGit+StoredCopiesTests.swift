import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeGitStoredCopiesTests {
  @Test func aPathHeadLacksHasNoCommittedSizeRatherThanAnError() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "hello\n")
    let git = WorktreeGit(runner: fixture.runner)

    #expect(try await git.committedSize(of: "a.txt", in: fixture.project.path) == 6)
    #expect(try await git.committedSize(of: "new.txt", in: fixture.project.path) == nil)
  }

  @Test func aGoneFilesStoredStartIsTheIndexsCopyCutToTheLengthAsked() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "hello world\n")
    try FileManager.default.removeItem(at: fixture.project.path.appending(path: "a.txt"))

    let start = await WorktreeGit(runner: fixture.runner).storedCopyStart(
      of: "a.txt",
      in: fixture.project.path,
      byteCount: 5,
      sizeLimit: 1 << 20,
    )

    #expect(start == Data("hello".utf8))
  }

  @Test func aPathThatLooksLikeAStageNumberIsReadFromTheIndex() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "1:notes.txt", content: "head\n")
    try fixture.write("staged\n", to: "1:notes.txt")
    _ = try await fixture.runner.run(["add", "--", "1:notes.txt"], in: fixture.project.path)
    try FileManager.default.removeItem(at: fixture.project.path.appending(path: "1:notes.txt"))

    let start = await WorktreeGit(runner: fixture.runner).storedCopyStart(
      of: "1:notes.txt",
      in: fixture.project.path,
      byteCount: 64,
      sizeLimit: 1 << 20,
    )

    #expect(start == Data("staged\n".utf8))
  }
}
