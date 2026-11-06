import Foundation
import MultishellCore
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorStatusTests {
  @Test func statusesRunAtMostEightAtATimeAndStillOverlap() async throws {
    let fake = try FakeGit.countingOverlap(replying: "printf '## main\\0'")
    defer { fake.tearDown() }
    let worktrees = (0..<20).map { number in
      Worktree(path: fake.directory, projectID: "/p", head: "h\(number)", branch: "b\(number)")
    }
    // Same directory, so ids collide; the count comes from the script.
    let coordinator = fake.coordinator

    let statuses = await coordinator.readStatuses(of: worktrees).mapValues(\.status)

    #expect(statuses.values.allSatisfy { $0.branch == "main" })
    let peaks = fake.overlaps
    #expect(peaks.count == 20, "every run recorded a peak")
    #expect(peaks.max() ?? 0 <= SharedReadState.maximumConcurrentReads, "\(peaks)")
    #expect(peaks.max() ?? 0 >= 4, "runs did not overlap: \(peaks)")
  }

  @Test func statusesOmitWorktreesWhoseDirectoryIsGone() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "ghost",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    let worktrees = try await fixture.git.list(fixture.project)
    try FileManager.default.removeItem(at: path)

    let statuses = await fixture.coordinator.readStatuses(of: worktrees).mapValues(\.status)

    #expect(statuses.keys.sorted() == [fixture.project.id])
  }
}
