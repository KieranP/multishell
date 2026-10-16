import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellGitKit

/// The per-file list every count is summed from; see Docs/design/files.md.
extension WorktreeGitStatusTests {
  private static func change(_ path: String, in status: WorktreeStatus) -> StatusChange? {
    status.changes.first { $0.path == path }
  }

  @Test func everyReadCountsEachNewFileInANewFolder() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    for name in ["a", "b", "c"] { try fixture.write("x\n", to: "new/\(name)") }
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    for indicator in GitStatusIndicator.allCases {
      let status = try await git.status(of: main, counting: indicator)
      #expect(status.untracked == 3, "\(indicator)")
      #expect(status.changedFiles == 3, "\(indicator)")
      #expect(status.untrackedPaths.sorted() == ["new/a", "new/b", "new/c"])
      #expect(status.summary.contains("3 untracked"))
    }
  }

  @Test func eachChangeIsListedByPathWithItsKindAndLines() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit(
      "seed",
      files: [
        "edited.txt": "a\nb\n", "gone.txt": "g\n", "run.sh": "echo\n",
        "image.bin": "one\n", ".gitattributes": "*.bin -diff\n",
      ],
    )
    try fixture.write("a\nB\nc\n", to: "edited.txt")
    try FileManager.default.removeItem(at: path.appending(path: "gone.txt"))
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: path.appending(path: "run.sh").path,
    )
    try fixture.write("two\n", to: "image.bin")
    try fixture.write("s\n", to: "staged.txt")
    _ = try await fixture.runner.run(["add", "staged.txt"], in: path)
    try fixture.write("1\n2\n", to: "with space/naïve\nname.txt")
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    let status = try await git.status(of: main)

    #expect(
      Set(status.changes) == [
        StatusChange(
          path: "edited.txt",
          kind: .modified,
          lines: .counted(insertions: 2, deletions: 1),
        ),
        StatusChange(
          path: "gone.txt",
          kind: .deleted,
          lines: .counted(insertions: 0, deletions: 1),
        ),
        StatusChange(path: "run.sh", kind: .modified, lines: .unscored),
        StatusChange(path: "image.bin", kind: .modified, lines: .unscored),
        StatusChange(
          path: "staged.txt",
          kind: .added,
          lines: .counted(insertions: 1, deletions: 0),
        ),
        StatusChange(
          path: "with space/naïve\nname.txt",
          kind: .added,
          lines: .counted(insertions: 2, deletions: 0),
        ),
      ]
    )
    #expect((status.insertions, status.deletions, status.unscoredFiles) == (5, 2, 2))
    #expect(status.changedFiles == 6)
  }

  @Test func stagedOnlyListsTheIndexAloneAndStillCountsEveryFile() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("seed", files: ["both.txt": "a\n", "loose.txt": "l\n"])
    try fixture.write("a\nb\n", to: "both.txt")
    _ = try await fixture.runner.run(["add", "both.txt"], in: path)
    try fixture.write("a\nb\nc\n", to: "both.txt")
    try fixture.write("l\nm\n", to: "loose.txt")
    try fixture.write("new\n", to: "new.txt")
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    let staged = try await git.status(of: main, counting: .stagedOnly)
    let everything = try await git.status(of: main, counting: .stagedAndUnstaged)

    #expect(
      staged.changes == [
        StatusChange(
          path: "both.txt",
          kind: .modified,
          lines: .counted(insertions: 1, deletions: 0),
        )
      ]
    )
    #expect(staged.changedFiles == 3, "the removal dialog counts every change")
    #expect(staged.untrackedPaths == ["new.txt"])
    #expect(
      Self.change("both.txt", in: everything)
        == StatusChange(
          path: "both.txt",
          kind: .modified,
          lines: .counted(insertions: 2, deletions: 0),
        )
    )
    #expect(everything.changes.count == 3)
  }

  @Test func aFileRemovedFromTheIndexAloneIsTwoChanges() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "keep.txt", content: "k\n")
    _ = try await fixture.runner.run(
      ["rm", "-q", "--cached", "keep.txt"],
      in: fixture.project.path,
    )
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    let status = try await git.status(of: main)

    #expect(
      status.changes.map { [$0.path, "\($0.kind)"] } == [
        ["keep.txt", "deleted"], ["keep.txt", "added"],
      ]
    )
    #expect(status.changedFiles == 2)
  }

  @Test func anUnmergedFileIsListedButNotCounted() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "f.txt", content: "a\nb\n")
    try await fixture.commitOnBranch("other", file: "f.txt", content: "x\nb\n", message: "theirs")
    try await fixture.commit("mine", file: "f.txt", content: "y\nb\n")
    _ = try? await fixture.runner.run(["merge", "other"], in: fixture.project.path)
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    for indicator in GitStatusIndicator.allCases {
      let status = try await git.status(of: main, counting: indicator)
      #expect(
        status.changes == [
          StatusChange(path: "f.txt", kind: .modified, lines: .notCounted)
        ],
        "\(indicator)",
      )
    }
  }

  @Test func beforeTheFirstCommitEveryStagedFileIsAnAddition() async throws {
    let fixture = try await RepositoryFixture.make(commit: false)
    defer { fixture.tearDown() }
    try fixture.write("one\n", to: "a.txt")
    _ = try await fixture.runner.run(["add", "a.txt"], in: fixture.project.path)
    try fixture.write("one\ntwo\n", to: "a.txt")
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    let status = try await git.status(of: main)

    #expect(
      status.changes == [
        StatusChange(
          path: "a.txt",
          kind: .added,
          lines: .counted(insertions: 2, deletions: 0),
        )
      ]
    )
  }

  @Test func newFilesPastTheLineCapAreListedAndNotCounted() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let total = UntrackedLineCounter.fileLimit + 5
    for index in 0..<total { try fixture.write("x\n", to: "many/\(index).txt") }
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)

    let status = try await git.status(of: main)

    #expect(status.changes.count == total)
    #expect(status.changes.filter { $0.lines == .notCounted }.count == 5)
    #expect(status.insertions == UntrackedLineCounter.fileLimit)
    #expect(status.changedFiles == total)
  }

  @Test func newFilesPastTheListedCapAreCountedButNotListed() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *status*) printf '## main\\0?? many/\\0' ;;
        *ls-files*) perl -e 'print "many/$_\\0" for 1..\(WorktreeGit.listedPathLimit + 7)' ;;
      esac
      """
    )
    defer { fake.tearDown() }
    let worktree = Worktree(path: fake.directory, projectID: fake.directory.path, head: "abc")

    let status = try await WorktreeGit(runner: fake.runner).status(of: worktree)

    #expect(status.untracked == WorktreeGit.listedPathLimit + 7)
    #expect(status.untrackedPaths.count == WorktreeGit.listedPathLimit)
    #expect(status.unlistedUntrackedFiles == 7)
    #expect(status.changedFiles == WorktreeGit.listedPathLimit + 7)
  }

  @Test func newFilesAreListedOnlyWhereStatusSawOne() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *status*) printf '## main\\0 M a.txt\\0' ;;
      esac
      """,
      loggingCalls: true,
    )
    defer { fake.tearDown() }
    let worktree = Worktree(path: fake.directory, projectID: fake.directory.path, head: "abc")

    for indicator in GitStatusIndicator.allCases {
      _ = try await WorktreeGit(runner: fake.runner).status(of: worktree, counting: indicator)
    }

    #expect(!FakeGit.calls(in: fake.directory).contains { $0.contains("ls-files") })
  }

  @Test func aFailedListOfNewFilesKeepsStatusCountOfThem() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *status*) printf '## main\\0?? new/\\0' ;;
        *ls-files*) exit 128 ;;
      esac
      """
    )
    defer { fake.tearDown() }
    let worktree = Worktree(path: fake.directory, projectID: fake.directory.path, head: "abc")

    let status = try await WorktreeGit(runner: fake.runner).status(of: worktree)

    #expect(status.isDirty)
    #expect(status.untracked == 1)
  }

  /// `ls-files --others` stands in for `status --untracked-files=all`, which
  /// costs git's untracked cache; this holds the two to the same files.
  @Test func theListOfNewFilesIsWhatStatusListsWithEveryFileShown() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("ignore", file: ".gitignore", content: "*.log\nbuild/\n")
    try fixture.write("x\n", to: "deep/er/one.txt")
    try fixture.write("x\n", to: "deep/two.txt")
    try fixture.write("x\n", to: "deep/skip.log")
    try fixture.write("x\n", to: "build/out.o")
    try fixture.write("x\n", to: "top.txt")
    let nested = path.appending(path: "nested", directoryHint: .isDirectory)
    try await TestRepository.initialise(at: nested, withFirstCommit: true, using: fixture.runner)
    try fixture.write("x\n", to: "nested/loose.txt")
    let git = WorktreeGit(runner: fixture.runner)
    let main = try #require(try await git.list(fixture.project).first)
    let everyFile = try await fixture.runner.run(
      ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
      in: path,
    )

    let status = try await git.status(of: main)

    let shown = WorktreeStatusParser.parse(everyFile).entries.filter(\.isUntracked).map(\.path)
    #expect(status.untrackedPaths.sorted() == shown.sorted())
    #expect(shown.contains("nested/"))
  }
}
