import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelControlDebugTests {
  @Test func theDebugReadingsAndThePanelAreRefusedWhileTheToolsAreOff() async {
    let harness = Harness()

    #expect(await harness.messageSource.ask(.debugSamples(last: 5)) == .refused(.debugToolsOff))
    #expect(await harness.messageSource.ask(.debugMemory) == .refused(.debugToolsOff))
    #expect(await harness.messageSource.ask(.debugGitRuns(last: 5)) == .refused(.debugToolsOff))
    #expect(await harness.messageSource.ask(.setDebugInfo(shown: true)) == .refused(.debugToolsOff))
    #expect(!harness.model.showsDebugInfo)
  }

  @Test func turningTheToolsOnAndOffFromTheCommandLineIsTheMenuItems() async {
    let harness = Harness()
    harness.model.debugSampler.interval = .seconds(3_600)

    #expect(await harness.messageSource.ask(.setDebugTools(enabled: true)) == .done)
    #expect(harness.model.areDebugToolsEnabled)
    #expect(await harness.messageSource.ask(.setDebugInfo(shown: true)) == .done)
    #expect(harness.model.showsDebugInfo)

    #expect(await harness.messageSource.ask(.setDebugInfo(shown: false)) == .done)
    #expect(!harness.model.showsDebugInfo)
    #expect(await harness.messageSource.ask(.setDebugTools(enabled: false)) == .done)
    #expect(!harness.model.areDebugToolsEnabled)
  }

  @Test func theSamplesAnswerTheNewestOnesOldestFirstInPlainNumbers() async throws {
    let harness = Harness()
    harness.model.enableDebugTools(scan: .sample(appMemory: 400, trees: []))
    for _ in 0..<3 { await harness.model.takeDebugSample() }

    let reply = try #require(await harness.messageSource.ask(.debugSamples(last: 2)))

    let samples = try #require(reply.outputObject as? [[String: Any]])
    #expect(samples.compactMap { $0["sequence"] as? Int } == [1, 2])
    #expect(samples.allSatisfy { $0["appMemory"] as? Int == 400 })
    #expect(samples.allSatisfy { $0["takenAt"] is String })
  }

  @Test func theMemoryAnswerHasEachLiveTabByTheIdTheListingGives() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.engine.terminalMemories[tab.focusedSessionID] = 50
    harness.model.enableDebugTools(scan: .sample(appMemory: 400, trees: []))
    await harness.model.takeDebugSample()

    let reply = try #require(await harness.messageSource.ask(.debugMemory))

    #expect(reply.outputFields["appMemory"] as? Int == 400)
    #expect(reply.outputFields["appMemoryOutsideTerminals"] as? Int == 350)
    let tabs = try #require(reply.outputFields["tabs"] as? [[String: Any]])
    #expect(tabs.compactMap { $0["id"] as? String } == [tab.id.uuidString])
    #expect(tabs.first?["terminalMemory"] as? Int == 50)
  }

  @Test func aMarkLandsInTheNextSampleAloneAndInTheTrace() async throws {
    let harness = Harness()
    harness.model.enableDebugTools()
    let next = harness.model.debugHistory.nextSequence

    let reply = try #require(
      await harness.messageSource.ask(.markDebugSample(name: "open 20 tabs"))
    )
    await harness.model.takeDebugSample()
    await harness.model.takeDebugSample()

    #expect(reply.outputFields["sample"] as? Int == next)
    #expect(harness.model.debugHistory.samples.map(\.marks) == [["open 20 tabs"], []])
    #expect(harness.platform.signposts == ["open 20 tabs"])
  }

  @Test func aMarkWithTheToolsOffGoesToTheTraceAndNoSample() async throws {
    let harness = Harness()

    let reply = try #require(await harness.messageSource.ask(.markDebugSample(name: "x")))

    #expect(reply.outputFields["sample"] is NSNull)
    #expect(harness.platform.signposts == ["x"])
  }

  @Test func eachGitRunIsAnsweredOnItsOwnWithTheSampleItEndedIn() async throws {
    let harness = Harness()
    harness.model.enableDebugTools()
    harness.model.debugGitRuns.append(
      [.sample("fetch", milliseconds: 40, peakMemory: 9), .sample("status")],
      inSample: 2,
    )

    let reply = try #require(await harness.messageSource.ask(.debugGitRuns(last: 1)))

    let runs = try #require(reply.outputObject as? [[String: Any]])
    #expect(runs.count == 1)
    #expect(runs.first?["command"] as? String == "status")
    #expect(runs.first?["sample"] as? Int == 2)
    #expect(runs.first?["milliseconds"] as? Double == 150)
  }

  @Test func theWindowOrAPaneIsScreenshotAsBase64AndOneNotDrawnIsRefused() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    harness.platform.workspaceWindowScreenshot = Data([1, 2, 3])
    harness.engine.screenshots[pane] = Data([4, 5])

    #expect(await harness.messageSource.ask(.screenshot(pane: nil)) == .output("AQID"))
    #expect(await harness.messageSource.ask(.screenshot(pane: pane)) == .output("BAU="))
    harness.platform.workspaceWindowScreenshot = nil
    #expect(await harness.messageSource.ask(.screenshot(pane: nil)) == .refused(.screenshotFailed))
  }

  @Test func aGitRunTheAppStartedIsAnsweredWithTheSampleItEndedIn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let git = try #require(harness.model.coordinator?.git)
    let worktree = try #require(harness.model.workspace.worktrees.first)
    harness.model.enableDebugTools()
    await harness.model.takeDebugSample()
    let sample = harness.model.debugHistory.nextSequence

    _ = await git.isRepository(worktree.path)
    await harness.model.takeDebugSample()
    let reply = await harness.model.answer(.debugGitRuns(last: 1_000))

    let runs = try #require(reply.outputObject as? [[String: Any]])
    let run = try #require(runs.first { $0["command"] as? String == "rev-parse --git-dir" })
    #expect(run["sample"] as? Int == sample)
    #expect(run["directory"] as? String == worktree.path.path)
  }

  @Test func aSummaryGivesEachReadingsLeastMeanAndMostOverTheTimeEachCovered() async throws {
    let harness = Harness()
    harness.model.enableDebugTools()
    harness.model.debugHistory.append(.sample(sequence: 0, framesPerSecond: 60, appCPUPercent: 10))
    harness.model.debugHistory.append(
      .sample(sequence: 1, framesPerSecond: 120, appCPUPercent: 40, elapsed: .seconds(2))
    )

    let reply = try #require(await harness.messageSource.ask(.debugSummary(last: 60)))

    #expect(reply.outputFields["sampleCount"] as? Int == 2)
    #expect(reply.outputFields["seconds"] as? Double == 3)
    let frames = try #require(reply.outputFields["framesPerSecond"] as? [String: Double])
    #expect(frames == ["least": 60, "mean": 100, "most": 120])
    let cpu = try #require(reply.outputFields["appCPUPercent"] as? [String: Double])
    #expect(cpu["mean"] == 30)
  }
}
