import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelServicePollingTests {
  @Test func aShownRunUnderWayHastensThePoll() async throws {
    let (harness, provider) = try await harnessReadNinetySecondsAgo(showing: .running)
    defer { harness.tearDown() }
    let callsBefore = provider.calls.count

    await harness.model.pollServices(interval: .seconds(3600))

    #expect(provider.calls.count > callsBefore)
  }

  @Test func aShownRunOfUnknownStatusLeavesThePollAtItsOwnPace() async throws {
    let (harness, provider) = try await harnessReadNinetySecondsAgo(showing: .unknown)
    defer { harness.tearDown() }
    let callsBefore = provider.calls.count

    await harness.model.pollServices(interval: .seconds(3600))

    #expect(provider.calls.count == callsBefore)
  }

  private func harnessReadNinetySecondsAgo(
    showing status: CIRunStatus
  ) async throws -> (GitHarness, FakeCIProvider) {
    let harness = try await GitHarness()
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [.sample(branch: "feat", status: status)])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let id = harness.project.id
    let backdated = harness.model.remoteState.readLog.begin(id, at: .now - .seconds(90))
    try #require(backdated)
    harness.model.remoteState.readLog.finish(id)
    return (harness, provider)
  }

  @Test func noPollStartsWhileTheAppIsInTheBackground() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    harness.platform.isActive = false

    harness.model.startServicePoll()

    #expect(harness.model.remoteState.servicePoll == nil)
  }

  @Test func aProjectIsNotCountedAskedBeforeAToolIsThereToAsk() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.pollServices()
    let (host, _) = harness.connectServices()
    await harness.model.pollServices()

    #expect(host.calls == ["list"], "due at once, not an interval after launch")
  }

  @Test func aReturnToTheFrontDuringAPollReadsWhatItMakesDueOnceThePollEnds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.addSecondProject()
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    let aMinuteAgo = ContinuousClock.now - .seconds(60)
    _ = harness.model.remoteState.readLog.begin(other.id, at: aMinuteAgo)
    harness.model.remoteState.readLog.finish(other.id)
    host.holdList()
    harness.model.startServicePoll()
    try await waitUntil { host.calls == ["list"] }

    harness.model.startServicePoll(interval: ServiceReadInterval.activation)
    host.releaseHeldReads()

    try await waitUntil({ host.calls.count == 2 }, seconds: 3)
    #expect(host.calls == ["list", "list"], "the other project, past the return's 30 s")
  }

  @Test func aHungReadHoldsUpNoPollRound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    host.holdList()
    let finished = Recorder<Bool>()

    Task {
      await harness.model.pollRound()
      finished.record(true)
    }
    try await waitUntil({ !finished.received.isEmpty }, seconds: 3)

    #expect(finished.received == [true])
    host.releaseHeldReads()
    try await waitUntil { harness.model.services(of: feat).pullRequest != nil }
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }
}
