import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelPersistenceTests {
  private func onDisk(_ file: URL) -> Workspace? {
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    return try? StateFile(fileURL: file).load()
  }

  /// The autosave loop holds the store and wakes only on a change, so the
  /// model going is what has to end it.
  @Test func aModelThatGoesLetsItsStoreGoToo() async throws {
    let file = Scratch.statePath("autosave")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    weak var store: WorkspaceStore?
    do {
      let harness = Harness(stateFile: file)
      store = harness.store
    }
    try await waitUntil { store == nil }

    #expect(store == nil)
  }

  @Test func aChangeReachesDiskWithoutAnyoneAskingAndSoDoesTheNext() async throws {
    let file = Scratch.statePath("autosave")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let harness = Harness(stateFile: file)

    harness.model.select(harness.main)
    try await waitUntil { onDisk(file)?.selectedWorktreeID != nil }
    let first = try #require(onDisk(file))
    #expect(first.selectedWorktreeID == harness.main.id)
    #expect(first.tabs.count == 1)

    // The observation has to be re-armed after it fires, or only the first
    // change of a session would ever be saved.
    harness.model.newTab()
    try await waitUntil { onDisk(file)?.tabs.count == 2 }
    let second = try #require(onDisk(file))
    #expect(second.tabs.count == 2)
  }

  @Test func aBurstOfChangesIsWrittenAfterItEndsAndTheLastStateWins() async throws {
    let file = Scratch.statePath("autosave")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let harness = Harness(stateFile: file)

    harness.model.select(harness.main)
    for _ in 0..<5 { harness.model.newTab() }
    harness.model.closeActiveTab()
    #expect(!FileManager.default.fileExists(atPath: file.path), "nothing written mid-burst")

    try await waitUntil { onDisk(file)?.tabs.count == 5 }
    let written = try #require(onDisk(file))
    #expect(written.tabs.count == 5)
  }

  @Test func saveNowFlushesWhatTheDebounceStillHolds() throws {
    let file = Scratch.statePath("autosave")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let harness = Harness(stateFile: file)

    harness.model.select(harness.main)
    harness.model.saveNow()

    #expect(try StateFile(fileURL: file).load().selectedWorktreeID == harness.main.id)
    #expect(harness.model.pendingSave == nil)
  }

  @Test func shellTitlesAndStatusesNeverTriggerASave() async throws {
    let file = Scratch.statePath("autosave")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let harness = Harness(stateFile: file)
    harness.model.select(harness.main)
    try await waitUntil { onDisk(file)?.selectedWorktreeID != nil }
    #expect(onDisk(file)?.selectedWorktreeID == harness.main.id)
    let written = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]
    // A finished task stays in place, so clear it: anything below that
    // schedules a save would put a new one here.
    harness.model.pendingSave = nil

    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    for i in 0..<10 {
      harness.engine.delegate?.terminalHost(
        harness.engine, didRetitle: tab.focusedSessionID, to: "t\(i)")
      harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: tab.focusedSessionID)
    }
    harness.model.statuses[harness.main.id] = WorktreeStatus()
    try await Task.sleep(for: .seconds(1))

    #expect(harness.model.pendingSave == nil)
    let after = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]
    #expect(written as? Date == after as? Date, "a prompt rewrote the state file")
  }

  @Test func aFailingSaveIsReportedOnceNotAfterEveryChange() async {
    // A file where a directory is needed: nothing can be created under it.
    let harness = Harness(stateFile: URL(fileURLWithPath: "/dev/null/multishell/state.json"))
    harness.model.presentedError = nil

    harness.model.saveOffMain()
    let first = await harness.presentedErrorArrives()
    #expect(first != nil)

    harness.model.saveOffMain()
    harness.model.saveOffMain()
    harness.model.presentedError = nil
    #expect(await harness.presentedErrorArrives() == nil, "the same alert, not a new one each time")
  }
}
