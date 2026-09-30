import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite(.serialized) @MainActor
struct AppModelPersistenceTests {
  private func stateFile() -> URL {
    Scratch.path("autosave").appendingPathComponent("state.json")
  }

  private func onDisk(_ file: URL) -> Workspace? {
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    return try? WorkspaceFile(fileURL: file).load()
  }

  /// The autosave loop holds the store and wakes only on a change, so the
  /// model going is what has to end it.
  @Test func aModelThatGoesLetsItsStoreGoToo() async throws {
    let file = stateFile()
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    weak var store: WorkspaceStore?
    do {
      let h = Harness(stateFile: file)
      store = h.store
    }
    try await waitUntil { store == nil }

    #expect(store == nil)
  }

  @Test func aChangeReachesDiskWithoutAnyoneAskingAndSoDoesTheNext() async throws {
    let file = stateFile()
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)

    h.model.select(h.main)
    try await waitUntil { onDisk(file)?.selectedWorktreeID != nil }
    let first = try #require(onDisk(file))
    #expect(first.selectedWorktreeID == h.main.id)
    #expect(first.tabs.count == 1)

    // The observation has to be re-armed after it fires, or only the first
    // change of a session would ever be saved.
    h.model.newTab()
    try await waitUntil { onDisk(file)?.tabs.count == 2 }
    let second = try #require(onDisk(file))
    #expect(second.tabs.count == 2)
  }

  @Test func aBurstOfChangesIsOneWriteAndTheLastStateWins() async throws {
    let file = stateFile()
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)

    h.model.select(h.main)
    for _ in 0..<5 { h.model.newTab() }
    h.model.closeActiveTab()
    #expect(!FileManager.default.fileExists(atPath: file.path), "nothing written mid-burst")

    try await waitUntil { onDisk(file)?.tabs.count == 5 }
    let written = try #require(onDisk(file))
    #expect(written.tabs.count == 5)
  }

  @Test func saveNowFlushesWhatTheDebounceStillHolds() throws {
    let file = stateFile()
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)

    h.model.select(h.main)
    h.model.saveNow()

    #expect(try WorkspaceFile(fileURL: file).load().selectedWorktreeID == h.main.id)
    #expect(h.model.pendingSave == nil)
  }

  @Test func shellTitlesAndStatusesNeverTriggerASave() async throws {
    let file = stateFile()
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)
    h.model.select(h.main)
    try await waitUntil { onDisk(file)?.selectedWorktreeID != nil }
    #expect(onDisk(file)?.selectedWorktreeID == h.main.id)
    let written = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]
    // A finished task stays in place, so clear it: anything below that
    // schedules a save would put a new one here.
    h.model.pendingSave = nil

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    for i in 0..<10 {
      h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "t\(i)")
      h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: tab.focusedSessionID)
    }
    h.model.statuses[h.main.id] = WorktreeStatus()
    try await Task.sleep(for: .seconds(1))

    #expect(h.model.pendingSave == nil)
    let after = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]
    #expect(written as? Date == after as? Date, "a prompt rewrote the state file")
  }

  @Test func aFailingSaveIsReportedOnceNotAfterEveryChange() async {
    // A file where a directory is needed: nothing can be created under it.
    let h = Harness(stateFile: URL(fileURLWithPath: "/dev/null/multishell/state.json"))
    h.model.presentedError = nil

    h.model.saveOffMain()
    let first = await h.presentedErrorArrives()
    #expect(first != nil)

    h.model.saveOffMain()
    h.model.saveOffMain()
    h.model.presentedError = nil
    #expect(await h.presentedErrorArrives() == nil, "the same alert, not a new one each time")
  }
}
