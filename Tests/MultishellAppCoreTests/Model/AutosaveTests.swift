import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

/// The autosave is what makes a relaunch look like the last session. It is
/// observation-driven and debounced, so both halves are checked: a change
/// reaches disk unprompted, and so does the change after that.
@Suite(.serialized) @MainActor
struct AutosaveTests {
  private func stateFile() -> URL {
    Scratch.path("autosave").appendingPathComponent("state.json")
  }

  /// The debounce is 300 ms. Polling rather than a fixed sleep keeps this
  /// fast on a quiet machine and honest on a loaded CI runner, where the
  /// other suites in this process compete for the main actor.
  private func saved(_ file: URL, until done: (Workspace) -> Bool) async throws -> Workspace {
    for _ in 0..<160 {
      if FileManager.default.fileExists(atPath: file.path) {
        let workspace = try WorkspaceSnapshot(fileURL: file).load()
        if done(workspace) { return workspace }
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    return try WorkspaceSnapshot(fileURL: file).load()
  }

  @Test func aChangeReachesDiskWithoutAnyoneAskingAndSoDoesTheNext() async throws {
    let file = stateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)

    h.model.select(h.main)
    let first = try await saved(file) { $0.selectedWorktreeID != nil }
    #expect(first.selectedWorktreeID == h.main.id)
    #expect(first.tabs.count == 1)

    // The observation has to be re-armed after it fires, or only the first
    // change of a session would ever be saved.
    h.model.newTab()
    let second = try await saved(file) { $0.tabs.count == 2 }
    #expect(second.tabs.count == 2)
  }

  @Test func aBurstOfChangesIsOneWriteAndTheLastStateWins() async throws {
    let file = stateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)

    h.model.select(h.main)
    for _ in 0..<5 { h.model.newTab() }
    h.model.closeActiveTab()
    #expect(!FileManager.default.fileExists(atPath: file.path), "nothing written mid-burst")

    let written = try await saved(file) { $0.tabs.count == 5 }
    #expect(written.tabs.count == 5)
  }

  @Test func saveNowFlushesWhatTheDebounceStillHolds() throws {
    let file = stateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)

    h.model.select(h.main)
    h.model.saveNow()

    #expect(try WorkspaceSnapshot(fileURL: file).load().selectedWorktreeID == h.main.id)
    #expect(h.model.pendingSave == nil)
  }

  @Test func shellTitlesAndStatusesNeverTriggerASave() async throws {
    let file = stateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)
    h.model.select(h.main)
    _ = try await saved(file) { $0.selectedWorktreeID != nil }
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
}
