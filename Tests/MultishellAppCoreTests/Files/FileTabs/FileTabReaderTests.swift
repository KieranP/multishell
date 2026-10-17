import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized)
struct FileTabReaderTests {
  private struct Repository {
    let root: URL
    let path: URL
    let runner: GitRunner
    var git: WorktreeGit { WorktreeGit(runner: runner) }

    static func make(commit: Bool = true) async throws -> Self {
      let runner = try TestGit.runner()
      let root = Scratch.path("filetab")
      let path = root.appending(path: "demo", directoryHint: .isDirectory)
      try await TestRepository.initialise(at: path, withFirstCommit: commit, using: runner)
      return Self(root: root, path: path, runner: runner)
    }

    func write(_ text: String, to file: String) throws {
      try text.write(to: path.appending(path: file), atomically: true, encoding: .utf8)
    }

    func read(_ file: String, previous: FileTabReading? = nil) async -> FileTabReading {
      await FileTabReader.read(
        path: file,
        in: path,
        git: git,
        diffAlgorithm: .histogram,
        previous: previous,
      )
    }

    func tearDown() { Scratch.remove(root) }
  }

  private static func text(_ reading: FileTabReading) -> FileTabRows? {
    if case .text(let text) = reading.content { text } else { nil }
  }

  @Test func aModifiedFileShowsEveryLineWithItsChangesAndStagedOnesMarked() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try await TestRepository.commit(
      "seed",
      files: ["a.txt": "one\ntwo\nthree\n"],
      in: repository.path,
      using: repository.runner,
    )
    try repository.write("ONE\ntwo\nthree\n", to: "a.txt")
    _ = try await repository.runner.run(["add", "a.txt"], in: repository.path)
    try repository.write("ONE\ntwo\nthree\nfour\n", to: "a.txt")

    let text = try #require(Self.text(await repository.read("a.txt")))

    #expect(text.lines.map(\.text) == ["one", "ONE", "two", "three", "four"])
    #expect(text.lines.map(\.kind) == [.removed, .added, .context, .context, .added])
    #expect(text.lines.map(\.isStaged) == [true, true, false, false, false])
    #expect(text.lineCounts == FileLineCounts(insertions: 2, deletions: 1))
  }

  @Test func anUntrackedFileIsEveryLineAddedAndAnUnchangedOneIsPlain() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try repository.write("x\r\ny\n", to: "new.txt")

    let new = try #require(Self.text(await repository.read("new.txt")))
    let plain = try #require(Self.text(await repository.read("README.md")))

    #expect(new.lines.map(\.text) == ["x", "y"])
    #expect(new.lines.allSatisfy { $0.kind == .added })
    #expect(plain.lines.map(\.kind) == [.context])
    #expect(!plain.hasLineChanges)
  }

  @Test func aFileDeletedBeforeTheTabOpenedShowsItsCommittedTextRemoved() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try FileManager.default.removeItem(at: repository.path.appending(path: "README.md"))

    let reading = await repository.read("README.md")

    #expect(reading.isFileGone)
    #expect(Self.text(reading)?.lines.map(\.kind) == [.removed])
  }

  @Test func aDeletedLatin1FilesCommittedTextIsDecodedAsATextEditorWould() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let file = repository.path.appending(path: "menu.txt")
    try Data([0x63, 0x61, 0x66, 0xE9, 0x0A]).write(to: file)
    _ = try await repository.runner.run(["add", "menu.txt"], in: repository.path)
    _ = try await repository.runner.run(["commit", "-q", "-m", "menu"], in: repository.path)
    try FileManager.default.removeItem(at: file)

    let reading = await repository.read("menu.txt")

    #expect(Self.text(reading)?.lines.map(\.text) == ["café"])
  }

  @Test func aFileDeletedUnderAnOpenTabKeepsItsLastTextUnmarked() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try repository.write("hello\nmore\n", to: "README.md")
    let before = await repository.read("README.md")
    try FileManager.default.removeItem(at: repository.path.appending(path: "README.md"))

    let after = await repository.read("README.md", previous: before)

    #expect(after.isFileGone)
    let text = try #require(Self.text(after))
    #expect(text.lines.map(\.text) == ["hello", "more"])
    #expect(text.lines.allSatisfy { $0.kind == .context })
  }

  @Test func aBinaryFileAModeChangeAndAFileTooLargeEachSaySo() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try Data([0x89, 0x50, 0x00]).write(to: repository.path.appending(path: "icon.png"))
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: repository.path.appending(path: "README.md").path,
    )
    try String(repeating: "x", count: FileTabReader.sizeLimit + 1).write(
      to: repository.path.appending(path: "big.txt"),
      atomically: true,
      encoding: .utf8,
    )

    #expect(await repository.read("icon.png").content == .binary(bytes: 3))
    #expect(Self.text(await repository.read("README.md"))?.hasModeChange == true)
    #expect(
      await repository.read("big.txt").content == .tooLarge(bytes: FileTabReader.sizeLimit + 1)
    )
  }

  @Test func aSmallFileWhoseLastCommitIsTooLargeIsNeverDiffed() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let huge = String(repeating: "y\n", count: FileTabReader.sizeLimit)
    try await TestRepository.commit(
      "huge",
      files: ["shrunk.txt": huge],
      in: repository.path,
      using: repository.runner,
    )
    try repository.write("small\n", to: "shrunk.txt")

    #expect(await repository.read("shrunk.txt").content == .tooLarge(bytes: huge.utf8.count))
  }

  @Test func beforeTheFirstCommitAStagedFileIsEveryLineAdded() async throws {
    let repository = try await Repository.make(commit: false)
    defer { repository.tearDown() }
    try repository.write("a\nb\n", to: "first.txt")
    _ = try await repository.runner.run(["add", "first.txt"], in: repository.path)

    let text = try #require(Self.text(await repository.read("first.txt")))

    #expect(text.lines.map(\.kind) == [.added, .added])
    #expect(text.lines.allSatisfy { $0.isStaged })
  }

  @Test func aNameThatLooksLikeAPatternIsReadLiterally() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try await TestRepository.commit(
      "odd",
      files: ["a[1].txt": "x\n", "a1.txt": "y\n"],
      in: repository.path,
      using: repository.runner,
    )
    try repository.write("y\nz\n", to: "a1.txt")

    #expect(Self.text(await repository.read("a[1].txt"))?.hasLineChanges == false)
  }

  @Test func aDeletedFilesTabReadAgainKeepsItsRemovedLines() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try FileManager.default.removeItem(at: repository.path.appending(path: "README.md"))
    let first = await repository.read("README.md")

    let second = await repository.read("README.md", previous: first)

    #expect(second == first)
  }
}
