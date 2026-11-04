import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelIntegrationSettingsTests {
  @Test func turningAnIntegrationOffDropsWhatItReadAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)

    #expect(harness.model.services(of: feat).pullRequest == nil)
    #expect(harness.model.ownSettings(of: harness.project).disabledIntegrations == [.gitHub])
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list"], "nothing asked of a host turned off")
  }

  @Test func settingsWrittenWithAnIntegrationOffDropWhatItReadAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    var settings = harness.model.ownSettings(of: harness.project)
    settings.setIntegration(.gitHub, isEnabled: false)
    harness.model.setSettings(settings, for: harness.project)

    #expect(harness.model.services(of: feat).pullRequest == nil)
  }

  @Test func settingsWrittenWithARepeatedIntegrationAreKeptInTheirOneForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    var settings = harness.model.ownSettings(of: harness.project)
    settings.disabledIntegrations = [.gitHub, .circleCI, .gitHub]

    harness.model.setSettings(settings, for: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).disabledIntegrations == [.circleCI, .gitHub]
    )
  }

  @Test func anIntegrationTurnedOffAndOnAgainSaysItsFailedReadWasNeverAnswered() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.failRecent(.loggedOut)
    harness.model.setIntegration(.circleCI, isEnabled: true, for: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let problem = try #require(harness.model.services(of: feat).readProblem)
    #expect(problem.lastAnsweredAt == nil)
  }

  @Test func anInstalledToolWithoutGitSaysSoRatherThanChecking() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    _ = try Scratch.script(
      "echo 'gh version 2.60.0 (2026-01-01)'",
      at: tools.appendingPathComponent("gh"),
    )
    harness.model.coordinator = nil
    await harness.model.adoptServiceTools(on: tools.path)

    await harness.model.refreshServiceToolStatuses()

    #expect(harness.model.integrationAvailability(.gitHub) == .needsGit)
  }

  @Test func closingTheIntegrationsPageStopsWantingToolStatuses() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.refreshServiceToolStatuses()

    harness.model.stopAskingToolStatuses()

    #expect(!harness.model.remoteState.wantsToolStatuses)
  }
}
