import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelPersistenceTests {
  @Test func theBoardsShowAllTerminalsIsKeptAcrossARelaunch() {
    let file = Scratch.statePath("shows-all-terminals")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)

    before.model.setShowsAllTerminals(true)

    let (after, _, _, error) = before.relaunched()
    #expect(error == nil)
    #expect(after.showsAllTerminals)
  }

  @Test func turningOnShowAllTerminalsReachesDiskWithoutAnyoneAsking() async throws {
    let file = Scratch.statePath("shows-all-terminals-autosave")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let harness = Harness(stateFile: file)

    harness.model.setShowsAllTerminals(true)

    try await waitUntil { onDisk(file)?.showsAllTerminals == true }
    #expect(onDisk(file)?.showsAllTerminals == true)
  }

  @Test func aPlainShellIsOnTheBoardAfterARelaunchThatKeptShowAllTerminals() {
    let file = Scratch.statePath("shows-all-terminals-board")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.select(before.main)
    before.model.setShowsAllTerminals(true)

    let (after, _, _, _) = before.relaunched()
    after.select(before.main)

    #expect(after.liveTerminalCount == 1)
    #expect(after.agentBoard.cardCount == 1)
    #expect(after.boardLaneCounts == [.idle: 1])
  }

  @Test func turningShowAllTerminalsBackOffIsKeptAcrossARelaunch() {
    let file = Scratch.statePath("shows-all-terminals-off")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.setShowsAllTerminals(true)
    before.model.saveNow()

    before.model.setShowsAllTerminals(false)

    let (after, _, _, _) = before.relaunched()
    #expect(!after.showsAllTerminals)
  }
}
