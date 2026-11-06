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
    let git = fixture.git

    #expect(try await git.committedSize(of: "a.txt", in: fixture.project.path) == 6)
    #expect(try await git.committedSize(of: "new.txt", in: fixture.project.path) == nil)
  }

  @Test func aGoneFilesStoredStartIsTheIndexsCopyCutToTheLengthAsked() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "hello world\n")
    try FileManager.default.removeItem(at: fixture.project.path.appending(path: "a.txt"))

    let start = await fixture.git.storedCopyStart(
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

    let start = await fixture.git.storedCopyStart(
      of: "1:notes.txt",
      in: fixture.project.path,
      byteCount: 64,
      sizeLimit: 1 << 20,
    )

    #expect(start == Data("staged\n".utf8))
  }

  @Test func aCopyIsReadByItsObjectIDWhereverHeadHasMovedSince() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("first", file: "logo.png", content: "one\n")
    let git = fixture.git
    let first = try #require(
      try await git.committedObjectID(of: "logo.png", in: fixture.project.path)
    )
    try await fixture.commit("second", file: "logo.png", content: "two\n")

    #expect(await git.objectBytes(first, in: fixture.project.path) == Data("one\n".utf8))
    #expect(try await git.objectSize(first, in: fixture.project.path) == 4)
  }

  @Test func anObjectIDGitCannotReadThrowsWhereAMissingCopyIsNil() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    #expect(
      try await fixture.git.committedObjectID(of: "new.png", in: fixture.project.path) == nil
    )
    await #expect(throws: (any Error).self) {
      try await fixture.git.committedObjectID(of: "new.png", in: fixture.root)
    }
  }

  @Test func aStoredCopyIsFoundInTheIndexOrHeadWithoutReadingIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "logo.png", content: "one\n")
    try fixture.write("staged\n", to: "staged.png")
    _ = try await fixture.runner.run(["add", "staged.png"], in: fixture.project.path)
    let git = fixture.git

    #expect(await git.hasStoredCopy(of: "logo.png", in: fixture.project.path))
    #expect(await git.hasStoredCopy(of: "staged.png", in: fixture.project.path))
    #expect(!(await git.hasStoredCopy(of: "new.png", in: fixture.project.path)))
  }

  @Test func aCommittedCopysObjectIDMovesOnlyWithItsBytes() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("first", file: "logo.png", content: "one\n")
    let git = fixture.git
    let first = try await git.committedObjectID(of: "logo.png", in: fixture.project.path)
    try await fixture.commit("other", file: "notes.txt", content: "x\n")
    let unmoved = try await git.committedObjectID(of: "logo.png", in: fixture.project.path)
    try await fixture.commit("second", file: "logo.png", content: "two\n")
    let moved = try await git.committedObjectID(of: "logo.png", in: fixture.project.path)

    #expect(first != nil)
    #expect(unmoved == first)
    #expect(moved != first)
    #expect(try await git.committedObjectID(of: "new.png", in: fixture.project.path) == nil)
  }
}
