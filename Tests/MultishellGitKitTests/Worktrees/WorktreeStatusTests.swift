import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct StatusConcurrencyTests {
  /// Each run holds its slot for a second: at half a second, a runner slow to spawn the next
  /// eight shells saw each wave leave before the next arrived, and read as serial.
  @Test func statusesRunAtMostEightAtATimeAndStillOverlap() async throws {
    let fake = try FakeGit.make(
      """
      mkdir -p "$SCRATCH/running" "$SCRATCH/peaks"
      : > "$SCRATCH/running/$$"
      ls "$SCRATCH/running" | wc -l > "$SCRATCH/peaks/$$"
      sleep 1
      rm "$SCRATCH/running/$$"
      printf '## main\\n'
      """)
    defer { fake.tearDown() }
    let worktrees = (0..<20).map {
      Worktree(path: fake.directory, projectID: "/p", head: "h\($0)", branch: "b\($0)")
    }
    // Same directory, so ids collide; the count comes from the script.
    let coordinator = WorktreeCoordinator(service: WorktreeService(git: fake.runner))

    let statuses = await coordinator.readStatuses(of: worktrees).mapValues(\.status)

    #expect(statuses.values.allSatisfy { $0.branch == "main" })
    let peaks = try FileManager.default.contentsOfDirectory(
      atPath: fake.directory.appendingPathComponent("peaks").path
    ).compactMap { name in
      try? String(
        contentsOf: fake.directory.appendingPathComponent("peaks/\(name)"), encoding: .utf8
      ).trimmingCharacters(in: .whitespacesAndNewlines)
    }.compactMap(Int.init)
    #expect(peaks.count == 20, "every run recorded a peak")
    #expect(peaks.max() ?? 0 <= WorktreeCoordinator.maxConcurrentStatuses, "\(peaks)")
    #expect(peaks.max() ?? 0 >= 4, "runs did not overlap: \(peaks)")
  }
}

@Suite(.serialized)
struct StatusLockTests {
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
    let main = try await repo.coordinator.refresh(repo.project)[0]

    let status = try await WorktreeService(git: repo.git).status(of: main)

    #expect(status.unstaged == 1, "the change was seen")
    #expect(try indexModified() == before, "the index was rewritten")
    #expect(
      !FileManager.default.fileExists(
        atPath: repo.project.path.appendingPathComponent(".git/index.lock").path))
  }
}
