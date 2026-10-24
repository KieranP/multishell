import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelLifecycleTests {
  @Test func launchStartsWithNothingSelectedAndNoShells() {
    let harness = Harness(savedSelection: true)
    #expect(harness.model.workspace.selectedWorktreeID == nil)
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func launchRefreshesTheFilesAndSweepsTheDropsOnceAndSaysWhatFailed() async throws {
    let harness = Harness()
    let calls = Recorder<String>()
    harness.model.refreshAppLaunchFiles = { _ in
      calls.record("refresh")
      throw CocoaError(.fileWriteNoPermission)
    }
    harness.model.sweepDropCopies = { calls.record("sweep") }

    await harness.model.start()

    try await waitUntil { calls.received.count == 2 }
    #expect(calls.received == ["refresh", "sweep"])
    #expect(
      harness.model.presentedError?.message
        == PresentedError(CocoaError(.fileWriteNoPermission)).message
    )
  }

  @Test func launchReturnsBeforeTheDroppedFileSweepFinishes() async throws {
    let harness = Harness()
    let events = Recorder<String>()
    harness.model.sweepDropCopies = {
      let giveUp = Date().addingTimeInterval(10)
      while !events.received.contains("open"), Date() < giveUp { usleep(1000) }
      events.record("finished")
    }

    await harness.model.start()
    let finishedFirst = events.received.contains("finished")
    events.record("open")

    #expect(!finishedFirst)
    try await waitUntil { events.received.contains("finished") }
    #expect(events.received.contains("finished"))
  }

  @Test func aSecondCopyOfTheAppHandsOverToTheRunningOneAndSavesNothing() async throws {
    let file = Scratch.statePath("second-copy")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let harness = Harness(stateFile: file)
    harness.model.saveDebounce = .zero
    harness.messageSource.startError = SocketFailure(kind: .inUse, path: "/tmp/multishell.sock")

    await harness.model.start()

    #expect(harness.platform.handedOverToRunningInstance)
    #expect(harness.model.statusPolling == nil, "this copy does nothing more")
    await harness.settled()
    harness.model.pendingSave = nil
    harness.model.select(harness.main)
    try await waitUntil { harness.model.pendingSave != nil }
    #expect(harness.model.pendingSave != nil, "the selection scheduled a save")
    await harness.model.pendingSave?.value
    await harness.settled()
    #expect(!FileManager.default.fileExists(atPath: file.path), "the debounce is a writer too")
    harness.model.saveNow()
    #expect(!FileManager.default.fileExists(atPath: file.path), "two writers of one file")
  }

  @Test func aCopyThatCouldNotQuitAfterHandingOverStartsNoShell() async {
    let harness = Harness()
    harness.messageSource.startError = SocketFailure(kind: .inUse, path: "/tmp/multishell.sock")
    await harness.model.start()

    harness.model.select(harness.main)
    harness.model.newTab()

    #expect(harness.engine.opened.isEmpty, "its config would outlive its quit")
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func quittingAsksOnlyWhileAShellIsLiveAndNoCommandLineQuitIsUnderWay() {
    let harness = Harness()
    #expect(!harness.model.asksBeforeQuitting)

    harness.model.select(harness.main)
    #expect(harness.model.asksBeforeQuitting)

    harness.model.quitsWithoutAsking = true
    #expect(!harness.model.asksBeforeQuitting)
  }
}
