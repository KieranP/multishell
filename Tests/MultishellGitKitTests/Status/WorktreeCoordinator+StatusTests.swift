import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeCoordinatorStatusTests {
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
    let coordinator = WorktreeCoordinator(git: WorktreeGit(runner: fake.runner))

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
    #expect(peaks.max() ?? 0 <= SharedGitReads.maxConcurrentReads, "\(peaks)")
    #expect(peaks.max() ?? 0 >= 4, "runs did not overlap: \(peaks)")
  }
}
