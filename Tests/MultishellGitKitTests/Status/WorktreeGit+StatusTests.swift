import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitStatusTests {
  /// Myers, git's default, reads this edit as +1 −6; `histogram` and
  /// `patience` read the same edit as +8 −13.
  private static let editBefore =
    "c\nc\na\nc\n\nc\n\nx\nc\nc\na\na\nb\nc\ny\n}\n}\na\n{\n}\n{\n}\nx\n{\ny\nc\na\nx\n\ny\n"
  private static let editAfter =
    "c\nc\na\nc\n\nx\nc\nc\na\na\nc\ny\n}\na\n{\n}\n{\n}\nb\nx\n{\ny\nc\nx\ny\n"

  /// A stale index makes a plain `git status` rewrite it under `index.lock`, which trips a
  /// commit typed at that moment; see Docs/design/worktrees.md.
  @Test func aStatusPollNeverWritesTheIndex() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let index = fixture.project.path.appendingPathComponent(".git/index")
    func indexModified() throws -> Date {
      try #require(
        FileManager.default.attributesOfItem(atPath: index.path)[.modificationDate] as? Date
      )
    }
    let before = try indexModified()
    try await Task.sleep(for: .milliseconds(50))
    try fixture.write("changed\n", to: "README.md")
    let main = try await fixture.worktree(onBranch: "main")

    let status = try await WorktreeGit(runner: fixture.runner).status(of: main)

    #expect(status.unstaged == 1, "the change was seen")
    #expect(try indexModified() == before, "the index was rewritten")
    #expect(
      !FileManager.default.fileExists(
        atPath: fixture.project.path.appendingPathComponent(".git/index.lock").path
      )
    )
  }

  /// `diff --numstat` refreshes stale stat data into a new index whatever
  /// `--no-optional-locks` says, and the watcher sees `.git` change.
  @Test func aLineCountBesideATouchedFileNeverWritesTheIndex() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let touched = path.appendingPathComponent("touched.txt")
    try "same\n".write(to: touched, atomically: true, encoding: .utf8)
    _ = try await fixture.runner.run(["add", "touched.txt"], in: path)
    _ = try await fixture.runner.run(["commit", "-qm", "touched"], in: path)
    let index = path.appendingPathComponent(".git/index").path
    func indexInode() throws -> Int {
      try #require(FileManager.default.attributesOfItem(atPath: index)[.systemFileNumber] as? Int)
    }
    let before = try indexInode()
    try Scratch.touch(touched)
    try fixture.write("changed\n", to: "README.md")
    let main = try await fixture.worktree(onBranch: "main")

    for indicator in GitStatusIndicator.allCases {
      let status = try await WorktreeGit(runner: fixture.runner).status(
        of: main,
        counting: indicator,
      )
      #expect(status.unstaged == 1)
    }

    #expect(try indexInode() == before, "the index was replaced")
  }

  @Test func beforeTheFirstCommitUnstagedLinesCountAsWellAsStagedOnes() async throws {
    let fixture = try await RepositoryFixture.make(commit: false)
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let file = path.appendingPathComponent("a.txt")
    try "one\n".write(to: file, atomically: true, encoding: .utf8)
    _ = try await fixture.runner.run(["add", "a.txt"], in: path)
    try "one\ntwo\nthree\n".write(to: file, atomically: true, encoding: .utf8)
    let git = WorktreeGit(runner: fixture.runner)
    let main = try await fixture.worktree(onBranch: "main")

    #expect(try await git.status(of: main, counting: .stagedAndUnstaged).insertions == 3)
    #expect(try await git.status(of: main, counting: .stagedOnly).insertions == 1)
  }

  @Test func aFailedCountSinceTheLastCommitNeverCountsFromTheEmptyTree() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *status*) printf '## main\\0 M a.txt\\0' ;;
        *diff-index*) exit 128 ;;
        *rev-parse*) exit 0 ;;
      esac
      """,
      loggingCalls: true,
    )
    defer { fake.tearDown() }
    let worktree = Worktree(path: fake.directory, projectID: fake.directory.path, head: "abc")

    _ = try await WorktreeGit(runner: fake.runner).status(of: worktree)

    #expect(!FakeGit.calls(in: fake.directory).contains { $0.contains("hash-object") })
  }

  @Test func theChosenDiffAlgorithmDecidesTheCountsForBothIndicators() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("base", files: ["edited.txt": Self.editBefore])
    try fixture.write(Self.editAfter, to: "edited.txt")
    _ = try await fixture.runner.run(["add", "edited.txt"], in: path)
    let git = WorktreeGit(runner: fixture.runner)
    let main = try await fixture.worktree(onBranch: "main")

    for indicator in GitStatusIndicator.allCases {
      let myers = try await git.status(of: main, counting: indicator, diffAlgorithm: .myers)
      let histogram = try await git.status(
        of: main,
        counting: indicator,
        diffAlgorithm: .histogram,
      )
      #expect((myers.insertions, myers.deletions) == (1, 6))
      #expect((histogram.insertions, histogram.deletions) == (8, 13))
    }
  }

  @Test func twoPeopleWithDifferentGitSettingsSeeTheSameCounts() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit(
      "base",
      files: ["edited.txt": Self.editBefore, "moved.txt": "one\ntwo\n"],
    )
    try fixture.write(Self.editAfter, to: "edited.txt")
    _ = try await fixture.runner.run(["add", "edited.txt"], in: path)
    _ = try await fixture.runner.run(["mv", "moved.txt", "renamed.txt"], in: path)
    let git = WorktreeGit(runner: fixture.runner)
    let main = try await fixture.worktree(onBranch: "main")
    var plain: [GitStatusIndicator: WorktreeStatus] = [:]
    for indicator in GitStatusIndicator.allCases {
      plain[indicator] = try await git.status(of: main, counting: indicator)
    }

    for (key, value) in [
      ("diff.algorithm", "myers"), ("diff.renames", "copies"), ("status.renames", "copies"),
    ] {
      _ = try await fixture.runner.run(["config", key, value], in: path)
    }

    for indicator in GitStatusIndicator.allCases {
      let counted = try #require(plain[indicator])
      #expect(try await git.status(of: main, counting: indicator) == counted)
      #expect(counted.changedFiles == 3, "a move is a file gone and a file added")
      #expect(counted.insertions == 10, "histogram's +8 and the move's +2")
      #expect(counted.deletions == 15)
      #expect(counted.unscoredFiles == 0)
    }
  }

  @Test func aChangedFileAndANewOneAreCountedApartAndTheStatusNamesTheBranch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let worktreeGit = WorktreeGit(runner: fixture.runner)
    let main = try await fixture.worktree(onBranch: "main")

    #expect(try await worktreeGit.status(of: main).isCleanAndInSync)

    try fixture.write("changed\n", to: "README.md")
    try fixture.write("new\n", to: "scratch.txt")
    let dirty = try await worktreeGit.status(of: main)

    #expect(dirty.unstaged == 1)
    #expect(dirty.untracked == 1)
    #expect(dirty.changedFiles == 2)
    #expect(dirty.branch == "main")
  }

  @Test func statusCountsLinesAddedAndRemovedAgainstHeadAndInUntrackedFiles() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let worktreeGit = WorktreeGit(runner: fixture.runner)
    try await fixture.commit("seed", file: "counted.txt", content: "a\nb\nc\n")
    let main = try await fixture.worktree(onBranch: "main")

    let clean = try await worktreeGit.status(of: main)
    #expect(clean.insertions == 0 && clean.deletions == 0)

    try fixture.write("a\nx\ny\nz\n", to: "counted.txt")
    try fixture.write("untracked\n", to: "loose.txt")
    let dirty = try await worktreeGit.status(of: main)

    #expect(dirty.insertions == 4)
    #expect(dirty.deletions == 2)
    #expect(dirty.summary.hasPrefix("+4 −2 · "))
  }

  @Test func aModeChangeAndANewBinaryFileCountAsFilesWithNoLines() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let worktreeGit = WorktreeGit(runner: fixture.runner)
    let script = fixture.project.path.appendingPathComponent("run.sh")
    try await fixture.commit("seed", file: "run.sh", content: "echo hi\n")
    let main = try await fixture.worktree(onBranch: "main")

    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: script.path,
    )
    try Data([0x89, 0x50, 0x00, 0x01]).write(
      to: fixture.project.path.appendingPathComponent("icon.png")
    )
    let status = try await worktreeGit.status(of: main)

    #expect(status.insertions == 0 && status.deletions == 0)
    #expect(status.unscoredFiles == 2, "the mode change and the new png")
    #expect(status.summary.contains("2 files with no lines to count"))
  }

  /// `git status` collapses an untracked directory to one entry while
  /// `ls-files --others` lists every file in it; see Docs/design/worktrees.md.
  @Test func eachFileInAnUntrackedDirectoryIsCountedWithItsLines() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let worktreeGit = WorktreeGit(runner: fixture.runner)
    try await fixture.commit("seed", file: "counted.txt", content: "a\n")
    let main = try await fixture.worktree(onBranch: "main")
    try fixture.write("a\nb\n", to: "fresh/one.txt")
    try fixture.write("c\nd\n", to: "fresh/two.txt")

    let status = try await worktreeGit.status(of: main)

    #expect(status.untracked == 2, "each file, not the one entry git status reports")
    #expect(status.changedFiles == 2)
    #expect(status.insertions == 4, "both files inside it, read through ls-files")
    #expect(status.unscoredFiles == 0)
  }

  /// An unmerged path prints `0 0` from `--numstat --cached`, which read as
  /// a file with no lines to count; the tooltip already says it is conflicted.
  @Test func aConflictedFileIsNotCountedAsAFileWithNoLines() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let worktreeGit = WorktreeGit(runner: fixture.runner)
    try await fixture.commit("seed", file: "f.txt", content: "a\nb\n")
    try await fixture.commitOnBranch("other", file: "f.txt", content: "x\nb\n", message: "theirs")
    try await fixture.commit("mine", file: "f.txt", content: "y\nb\n")
    _ = try? await fixture.runner.run(["merge", "other"], in: fixture.project.path)
    let main = try await fixture.worktree(onBranch: "main")

    let staged = try await worktreeGit.status(of: main, counting: .stagedOnly)

    #expect(staged.conflicted == 1)
    #expect(staged.unscoredFiles == 0, "the conflict is not a binary file or a rename")
  }

  @Test func stagedOnlyCountsTheIndexAndNoUntrackedFile() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let worktreeGit = WorktreeGit(runner: fixture.runner)
    try await fixture.commit("seed", file: "counted.txt", content: "a\nb\nc\n")
    let main = try await fixture.worktree(onBranch: "main")

    try fixture.write("a\nx\ny\nz\n", to: "counted.txt")
    try fixture.write("untracked\n", to: "loose.txt")

    let beforeStaging = try await worktreeGit.status(of: main, counting: .stagedOnly)
    #expect(
      beforeStaging.insertions == 0 && beforeStaging.deletions == 0
        && beforeStaging.unscoredFiles == 0
    )

    _ = try await fixture.runner.run(["add", "counted.txt"], in: fixture.project.path)
    let staged = try await worktreeGit.status(of: main, counting: .stagedOnly)
    #expect(staged.insertions == 3)
    #expect(staged.deletions == 2)
  }
}
