import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
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

    func read(
      _ file: String,
      since base: DefaultBranch? = nil,
      previous: FileTabReading? = nil,
    ) async -> FileTabReading {
      await FileTabReader.read(
        path: file,
        in: path,
        git: git,
        diffAlgorithm: .histogram,
        since: base,
        previous: previous,
      )
    }

    /// `main`, as a project with no remote resolves it.
    func base() async throws -> DefaultBranch {
      try #require(
        DefaultBranch.resolve(
          from: await git.branchRefs(Project(path: path))?.refs ?? [],
          override: nil,
        )
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

  @Test func sinceTheBaseAFileShowsWhatItsBranchCommittedWithNoStagingMarked() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try await TestRepository.commit(
      "seed",
      files: ["a.txt": "one\n", "gone.txt": "gone\n"],
      in: repository.path,
      using: repository.runner,
    )
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try await TestRepository.commit(
      "work",
      files: ["a.txt": "one\ntwo\n"],
      in: repository.path,
      using: repository.runner,
    )
    _ = try await repository.runner.run(["rm", "-q", "gone.txt"], in: repository.path)
    _ = try await repository.runner.run(["commit", "-q", "-m", "drop"], in: repository.path)
    try repository.write("one\ntwo\nthree\n", to: "a.txt")

    let edited = try #require(Self.text(await repository.read("a.txt", since: base)))
    let deleted = await repository.read("gone.txt", since: base)

    #expect(edited.lines.map(\.kind) == [.context, .added, .added])
    #expect(!edited.displayText.marksStaging)
    #expect(deleted.isFileGone)
    #expect(Self.text(deleted)?.lines.map(\.kind) == [.removed], "the base's text, removed")
  }

  @Test func sinceTheBaseAFileTheBranchAddedThenDeletedShowsHeadsTextRemoved() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try await TestRepository.commit(
      "add",
      files: ["new.txt": "new\n"],
      in: repository.path,
      using: repository.runner,
    )
    try FileManager.default.removeItem(at: repository.path.appending(path: "new.txt"))

    let reading = await repository.read("new.txt", since: base)

    #expect(reading.isFileGone)
    #expect(Self.text(reading)?.lines.map(\.kind) == [.removed], "HEAD's text, removed")
  }

  @Test func sinceTheBaseAFileGitNeverHadThatIsGoneIsMissingNotUnreadable() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "work\n"],
      in: repository.path,
      using: repository.runner,
    )
    try repository.write("new\n", to: "new.txt")
    try FileManager.default.removeItem(at: repository.path.appending(path: "new.txt"))

    let reading = await repository.read("new.txt", since: base)

    #expect(reading.isFileGone)
    #expect(reading.content == .missing)
  }

  @Test func aTabWhoseMergeBaseGitCannotReadKeepsWhatItLastShowed() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try await TestRepository.commit(
      "more",
      files: ["README.md": "hello\nmore\n"],
      in: repository.path,
      using: repository.runner,
    )
    let first = await repository.read("README.md", since: base)
    try #require(Self.text(first)?.lineCounts == FileLineCounts(insertions: 1, deletions: 0))
    _ = try await repository.runner.run(["branch", "-q", "-D", "main"], in: repository.path)

    let again = await repository.read("README.md", since: base, previous: first)

    #expect(again == first, "not quietly diffed against HEAD instead")
  }

  @Test func aTabOnABranchSharingNoHistoryWithTheBaseCountsFromHeadAndKeepsUp() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(
      ["checkout", "-q", "--orphan", "alone"],
      in: repository.path,
    )
    try await TestRepository.commit(
      "alone",
      files: ["README.md": "alone\n"],
      in: repository.path,
      using: repository.runner,
    )
    let first = await repository.read("README.md", since: base)
    try repository.write("alone\nedited\n", to: "README.md")

    let again = await repository.read("README.md", since: base, previous: first)

    #expect(Self.text(again)?.lineCounts == FileLineCounts(insertions: 1, deletions: 0))
  }

  @Test func aMergeBaseGitCannotReadShowsNoRowsRatherThanAGuessWhereNoneAreKept() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    _ = try await repository.runner.run(["branch", "-q", "-D", "main"], in: repository.path)
    try FileManager.default.removeItem(at: repository.path.appending(path: "README.md"))
    let released = FileTabReading(content: .released(changeKind: nil), isFileGone: false)

    let reading = await repository.read("README.md", since: base, previous: released)

    #expect(Self.text(reading) == nil, "not counted from HEAD unseen")
    #expect(reading.isFileGone, "but struck as the file is")
  }

  @Test func onTheBaseItselfABranchTabStillMarksWhatIsStaged() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try repository.write("hello\nstaged\n", to: "README.md")
    _ = try await repository.runner.run(["add", "README.md"], in: repository.path)

    let text = try #require(Self.text(await repository.read("README.md", since: base)))

    #expect(text.displayText.marksStaging)
    let added = text.lines.filter { $0.kind == .added }
    #expect(!added.isEmpty && added.allSatisfy { $0.isStaged })
  }

  @Test func sinceTheBaseAFileTheBranchDeletedThenWroteAgainShowsItsTextOnDisk() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    _ = try await repository.runner.run(["rm", "-q", "README.md"], in: repository.path)
    _ = try await repository.runner.run(["commit", "-q", "-m", "drop"], in: repository.path)
    try repository.write("again\n", to: "README.md")

    let text = try #require(Self.text(await repository.read("README.md", since: base)))

    #expect(text.lines.map(\.text) == ["again"])
    #expect(text.lines.map(\.kind) == [.added])
  }

  @Test func anIgnoredFileTakenOutOfTheIndexShowsItsLinesRemovedAsTheListDoes() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    try repository.write("README.md\n", to: ".gitignore")
    _ = try await repository.runner.run(
      ["rm", "-q", "--cached", "README.md"],
      in: repository.path,
    )

    let text = try #require(Self.text(await repository.read("README.md")))

    #expect(text.lines.map(\.kind) == [.removed])
  }

  @Test func sinceTheBaseAFileTheBranchAddedThenDeletedMarksNoStaging() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try await TestRepository.commit(
      "add",
      files: ["new.txt": "new\n"],
      in: repository.path,
      using: repository.runner,
    )
    try FileManager.default.removeItem(at: repository.path.appending(path: "new.txt"))

    let text = try #require(Self.text(await repository.read("new.txt", since: base)))

    #expect(!text.displayText.marksStaging)
  }

  @Test func aDeletionStagedWithGitRmMarksItsRemovedLinesStaged() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    _ = try await repository.runner.run(["rm", "-q", "README.md"], in: repository.path)

    let reading = await repository.read("README.md")

    #expect(Self.text(reading)?.lines.map(\.isStaged) == [true])
  }

  @Test func aCopyAtTheMergeBaseGitCannotSizeKeepsWhatTheTabLastShowed() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *merge-base*) echo aaaa ;;
        *rev-parse*) echo bbbb ;;
        *cat-file*) exit 2 ;;
      esac
      """
    )
    defer { fake.tearDown() }
    try "kept\n".write(
      to: fake.directory.appending(path: "a.txt"),
      atomically: true,
      encoding: .utf8,
    )
    let base = DefaultBranch(
      shortName: "main",
      nameWithoutRemote: "main",
      tip: "aaaa",
      fullName: "refs/heads/main",
    )
    let previous = FileTabReading(
      content: .text(
        FileTabRows(
          lines: [DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "kept")],
          marksStaging: false,
        )
      ),
      isFileGone: false,
    )

    let reading = await FileTabReader.read(
      path: "a.txt",
      in: fake.directory,
      git: WorktreeGit(runner: fake.runner),
      diffAlgorithm: .histogram,
      since: base,
      previous: previous,
    )

    #expect(reading == previous, "not read as a file new since the base")
  }

  @Test func aFirstReadWhoseCommittedSizeGitCannotReadNeverDrawsTheFileAsNew() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *cat-file*) exit 2 ;;
      esac
      """
    )
    defer { fake.tearDown() }
    try "kept\n".write(
      to: fake.directory.appending(path: "a.txt"),
      atomically: true,
      encoding: .utf8,
    )

    let reading = await FileTabReader.read(
      path: "a.txt",
      in: fake.directory,
      git: WorktreeGit(runner: fake.runner),
      diffAlgorithm: .histogram,
      since: nil,
      previous: nil,
    )

    #expect(reading.content == .unreadable, "said so, not every line added")
  }

  @Test func aGoneFilesCopyInHeadGitCannotSizeIsNoAnswerNotAMissingFile() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *merge-base*) echo aaaa ;;
        *rev-parse*) echo bbbb ;;
        *cat-file*aaaa*) exit 128 ;;
        *cat-file*) exit 2 ;;
      esac
      """
    )
    defer { fake.tearDown() }
    let base = DefaultBranch(
      shortName: "main",
      nameWithoutRemote: "main",
      tip: "aaaa",
      fullName: "refs/heads/main",
    )

    let reading = await FileTabReader.read(
      path: "gone.txt",
      in: fake.directory,
      git: WorktreeGit(runner: fake.runner),
      diffAlgorithm: .histogram,
      since: base,
      previous: nil,
    )

    #expect(reading.content == .unreadable)
  }

  @Test func sinceTheBaseANewFileIsEveryLineAddedWithNoStagingMarked() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "work\n"],
      in: repository.path,
      using: repository.runner,
    )
    try repository.write("x\n", to: "new.txt")

    let new = try #require(Self.text(await repository.read("new.txt", since: base)))

    #expect(new.lines.map(\.kind) == [.added])
    #expect(!new.displayText.marksStaging)
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

  @Test func aDeletedBinaryFileSaysItsCommittedSize() async throws {
    let repository = try await Repository.make()
    defer { repository.tearDown() }
    let file = repository.path.appending(path: "icon.png")
    try Data([0x89, 0x50, 0x00, 0x01]).write(to: file)
    _ = try await repository.runner.run(["add", "icon.png"], in: repository.path)
    _ = try await repository.runner.run(["commit", "-q", "-m", "icon"], in: repository.path)
    try FileManager.default.removeItem(at: file)

    let reading = await repository.read("icon.png")

    #expect(reading.content == .binary(bytes: 4))
    #expect(reading.isFileGone)
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
