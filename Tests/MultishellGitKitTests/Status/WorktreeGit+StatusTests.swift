import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitStatusTests {
  /// A stale index makes a plain `git status` rewrite it under `index.lock`, which trips a
  /// commit typed at that moment; see Docs/design/worktrees.md.
  @Test func aStatusPollNeverWritesTheIndex() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let index = repo.project.path.appendingPathComponent(".git/index")
    func indexModified() throws -> Date {
      try #require(
        FileManager.default.attributesOfItem(atPath: index.path)[.modificationDate] as? Date)
    }
    let before = try indexModified()
    try await Task.sleep(for: .milliseconds(50))
    try "changed\n".write(
      to: repo.project.path.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    let main = try await repo.coordinator.git.list(repo.project)[0]

    let status = try await WorktreeGit(runner: repo.git).status(of: main)

    #expect(status.unstaged == 1, "the change was seen")
    #expect(try indexModified() == before, "the index was rewritten")
    #expect(
      !FileManager.default.fileExists(
        atPath: repo.project.path.appendingPathComponent(".git/index.lock").path))
  }

  @Test func statusReflectsWorkingTreeChangesAndBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let project = repo.project
    let worktreeGit = WorktreeGit(runner: repo.git)
    let main = try await worktreeGit.list(project)[0]

    #expect(try await worktreeGit.status(of: main).isClean)

    try "changed\n".write(
      to: project.path.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    try "new\n".write(
      to: project.path.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)
    let dirty = try await worktreeGit.status(of: main)

    #expect(dirty.unstaged == 1)
    #expect(dirty.untracked == 1)
    #expect(dirty.changedFiles == 2)
    #expect(dirty.branch == "main")
  }

  @Test func statusCountsLinesAddedAndRemovedAgainstHead() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "counted.txt", content: "a\nb\nc\n")
    let main = try await worktreeGit.list(repo.project)[0]

    let clean = try await worktreeGit.status(of: main)
    #expect(clean.insertions == 0 && clean.deletions == 0)

    try "a\nx\ny\nz\n".write(
      to: repo.project.path.appendingPathComponent("counted.txt"), atomically: true,
      encoding: .utf8)
    try "untracked\n".write(
      to: repo.project.path.appendingPathComponent("loose.txt"), atomically: true, encoding: .utf8)
    let dirty = try await worktreeGit.status(of: main)

    #expect(dirty.insertions == 4)
    #expect(dirty.deletions == 2)
    #expect(dirty.summary.hasPrefix("+4 −2 · "))
  }

  @Test func aModeChangeAndANewBinaryFileCountAsFilesWithNoLines() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    let script = repo.project.path.appendingPathComponent("run.sh")
    try await repo.commit("seed", file: "run.sh", content: "echo hi\n")
    let main = try await worktreeGit.list(repo.project)[0]

    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: script.path)
    try Data([0x89, 0x50, 0x00, 0x01]).write(
      to: repo.project.path.appendingPathComponent("icon.png"))
    let status = try await worktreeGit.status(of: main)

    #expect(status.insertions == 0 && status.deletions == 0)
    #expect(status.unscoredFiles == 2, "the mode change and the new png")
    #expect(status.summary.contains("2 files with no lines to count"))
  }

  /// `git status` collapses an untracked directory to one entry while
  /// `ls-files --others` lists every file in it; see Docs/design/worktrees.md.
  @Test func anUntrackedDirectoryIsOneEntryWhoseLinesAreStillCounted() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "counted.txt", content: "a\n")
    let main = try await worktreeGit.list(repo.project)[0]
    let fresh = repo.project.path.appendingPathComponent("fresh", isDirectory: true)
    try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
    try "a\nb\n".write(
      to: fresh.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    try "c\nd\n".write(
      to: fresh.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)

    let status = try await worktreeGit.status(of: main)

    #expect(status.untracked == 1, "the directory, which is what git reports")
    #expect(status.changedFiles == 1)
    #expect(status.insertions == 4, "both files inside it, read through ls-files")
    #expect(status.unscoredFiles == 0)
  }

  /// An unmerged path prints `0 0` from `--numstat --cached`, which read as
  /// a file with no lines to count; the tooltip already says it is conflicted.
  @Test func aConflictedFileIsNotCountedAsAFileWithNoLines() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "f.txt", content: "a\nb\n")
    _ = try await repo.git.run(["checkout", "-q", "-b", "other"], in: repo.project.path)
    try await repo.commit("theirs", file: "f.txt", content: "x\nb\n")
    _ = try await repo.git.run(["checkout", "-q", "main"], in: repo.project.path)
    try await repo.commit("mine", file: "f.txt", content: "y\nb\n")
    _ = try? await repo.git.run(["merge", "other"], in: repo.project.path)
    let main = try await worktreeGit.list(repo.project)[0]

    let staged = try await worktreeGit.status(of: main, counting: .stagedOnly)

    #expect(staged.conflicted == 1)
    #expect(staged.unscoredFiles == 0, "the conflict is not a binary file or a rename")
  }

  @Test func stagedOnlyCountsTheIndexAndNoUntrackedFile() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "counted.txt", content: "a\nb\nc\n")
    let main = try await worktreeGit.list(repo.project)[0]

    try "a\nx\ny\nz\n".write(
      to: repo.project.path.appendingPathComponent("counted.txt"), atomically: true,
      encoding: .utf8)
    try "untracked\n".write(
      to: repo.project.path.appendingPathComponent("loose.txt"), atomically: true, encoding: .utf8)

    let unstaged = try await worktreeGit.status(of: main, counting: .stagedOnly)
    #expect(unstaged.insertions == 0 && unstaged.deletions == 0 && unstaged.unscoredFiles == 0)

    _ = try await repo.git.run(["add", "counted.txt"], in: repo.project.path)
    let staged = try await worktreeGit.status(of: main, counting: .stagedOnly)
    #expect(staged.insertions == 3)
    #expect(staged.deletions == 2)
  }
}
