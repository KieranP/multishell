import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelLifecycleTests {
  @Test func launchStartsWithNothingSelectedAndNoShells() {
    let h = Harness(savedSelection: true)
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.liveTerminalCount == 0)
    #expect(
      h.model.presentedError?.title == "git not found", "no git was injected, and that is reported")
  }

  @Test func launchRefreshesTheFilesAndSweepsTheDropsOnceAndSaysWhatFailed() async throws {
    let h = Harness()
    let calls = LineRecorder()
    h.model.refreshAppLaunchFiles = { _ in
      calls.record("refresh")
      return CocoaError(.fileWriteNoPermission)
    }
    h.model.sweepPromisedDropCopies = { calls.record("sweep") }

    await h.model.start()

    try await waitUntil { calls.received.count == 2 }
    #expect(calls.received == ["refresh", "sweep"])
    #expect(
      h.model.presentedError?.message
        == PresentedError(CocoaError(.fileWriteNoPermission)).message)
  }

  @Test func launchOpensTerminalsWithoutWaitingForTheDroppedFileSweep() async throws {
    let h = Harness()
    let gate = LineRecorder()
    h.model.sweepPromisedDropCopies = {
      let giveUp = Date().addingTimeInterval(10)
      while !gate.received.contains("open"), Date() < giveUp { usleep(1000) }
      gate.record("finished")
    }

    await h.model.start()
    let finishedFirst = gate.received.contains("finished")
    gate.record("open")

    #expect(!finishedFirst)
    try await waitUntil { gate.received.contains("finished") }
  }

  @Test func aSecondCopyOfTheAppHandsOverToTheRunningOneAndSavesNothing() async {
    let file = Scratch.path("second-copy").appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)
    h.source.startError = SocketFailure(kind: .inUse, path: "/tmp/multishell.sock")

    await h.model.start()

    #expect(h.platform.handedOverToRunningInstance)
    #expect(h.model.statusPolling == nil, "this copy does nothing more")
    h.model.select(h.main)
    try? await Task.sleep(for: .milliseconds(600))
    #expect(!FileManager.default.fileExists(atPath: file.path), "the debounce is a writer too")
    h.model.saveNow()
    #expect(!FileManager.default.fileExists(atPath: file.path), "two writers of one file")
  }

  @Test func aCopyThatCouldNotQuitAfterHandingOverStartsNoShell() async {
    let h = Harness()
    h.source.startError = SocketFailure(kind: .inUse, path: "/tmp/multishell.sock")
    await h.model.start()

    h.model.select(h.main)
    h.model.newTab()

    #expect(h.engine.opened.isEmpty, "its config would outlive its quit")
    #expect(h.model.liveTerminalCount == 0)
  }
}
