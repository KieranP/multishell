import Foundation
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitCreationTests {
  @Test func anAlreadyStoppedStopperSkipsTheIndexRefresh() async throws {
    let fake = try FakeGit.make("", loggingCalls: true)
    defer { fake.tearDown() }
    let stopper = ProcessStopper()
    stopper.stop()

    await WorktreeGit(runner: fake.runner).settleIndex(of: fake.directory, stopper: stopper)

    #expect(!FakeGit.calls(in: fake.directory).contains { $0.contains("update-index") })
  }
}
