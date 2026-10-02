import Foundation
import MultishellCore
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
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
    let coordinator = fake.coordinator

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
    #expect(peaks.max() ?? 0 <= SharedReadState.maxConcurrentReads, "\(peaks)")
    #expect(peaks.max() ?? 0 >= 4, "runs did not overlap: \(peaks)")
  }

  @Test func statusesOmitWorktreesWhoseDirectoryIsGone() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "ghost", in: fixture.project, settings: fixture.worktreeSettings)
    let worktrees = try await fixture.coordinator.git.list(fixture.project)
    try FileManager.default.removeItem(at: path)

    let statuses = await fixture.coordinator.readStatuses(of: worktrees).mapValues(\.status)

    #expect(statuses.keys.sorted() == [fixture.project.id])
  }
}
