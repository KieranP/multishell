import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlAppTests {
  @Test func theAppDescribesItselfByPidAndStateFile() async throws {
    let harness = Harness()

    let reply = try #require(await harness.messageSource.ask(.info))

    #expect(reply.outputFields["pid"] as? Int == Int(ProcessInfo.processInfo.processIdentifier))
    #expect(reply.outputFields["stateFile"] as? String == Paths.stateFile.path)
    #expect(reply.outputFields["areDebugToolsEnabled"] as? Bool == false)
  }

  @Test func theInfoListsTheOpenWindows() async throws {
    let harness = Harness()
    harness.platform.windows = [
      PlatformWindow(
        identifier: "main",
        title: "Multishell",
        isKey: true,
        width: 1_200,
        height: 800,
        isFullScreen: false,
        sheet: nil,
      )
    ]

    let reply = try #require(await harness.messageSource.ask(.info))

    let windows = try #require(reply.outputFields["windows"] as? [[String: Any]])
    #expect(windows.compactMap { $0["identifier"] as? String } == ["main"])
    #expect(windows.first?["width"] as? Double == 1_200)
  }

  @Test func aQuitSkipsTheConfirmationButIsRefusedOverAWorkingAgentUnlessForced() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID)
    )

    #expect(await harness.messageSource.ask(.quit(force: false)) == .refused(.agentWorking))
    await harness.settled()
    #expect(harness.platform.quitCount == 0)

    #expect(await harness.messageSource.ask(.quit(force: true)) == .done)
    await harness.settled()
    #expect(harness.platform.quitCount == 1)
  }

  @Test func aQuitThatDoesNotEndTheAppLeavesTheNextOneAskingAgain() async throws {
    let harness = Harness()
    var skippedTheQuestion: [Bool] = []
    harness.platform.onQuit = { skippedTheQuestion.append(harness.model.quitsWithoutAsking) }

    #expect(await harness.messageSource.ask(.quit(force: true)) == .done)
    await harness.settled()

    #expect(skippedTheQuestion == [true])
    #expect(!harness.model.quitsWithoutAsking)
  }
}
