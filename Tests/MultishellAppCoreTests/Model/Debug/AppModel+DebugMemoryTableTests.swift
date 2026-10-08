import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugMemoryTableTests {
  private func harnessWithTwoTabs() throws -> (Harness, TerminalTab, TerminalTab) {
    let (harness, _) = Harness.withOnePane()
    harness.model.newTab()
    let tabs = harness.model.workspace.tabs
    try #require(tabs.count == 2)
    return (harness, tabs[0], tabs[1])
  }

  private func placeTree(of pid: Int32, in tab: TerminalTab, _ harness: Harness) {
    harness.engine.processHints[tab.focusedSessionID] = TerminalProcessHint(
      terminalPath: nil, foregroundPID: pid)
  }

  @Test func eachTabIsGivenTheProcessesItsPaneRunsAndTheRestAreUnattributed() async throws {
    let (harness, session) = Harness.withOnePane()
    harness.engine.processHints[session.id] = TerminalProcessHint(
      terminalPath: nil, foregroundPID: 11)
    harness.model.enableDebugTools(
      scan: .sample(appMemory: 400, trees: [(10, [10, 11]), (20, [20])]))

    await harness.model.takeDebugSample()

    let table = harness.model.debugMemoryTable
    let tab = try #require(table.tabs.first)
    #expect(table.tabs.count == 1)
    #expect(tab.processList.processes.map(\.pid).sorted() == [10, 11])
    #expect(tab.location.worktreeName == harness.model.displayName(of: harness.main))
    #expect(table.unattributed.processes.map(\.pid) == [20])
    #expect(tab.processList.totalMemory == 200)
    #expect(table.unattributed.totalMemory == 100)
    #expect(table.totalMemory == 700)
  }

  @Test func aTabWhoseShellIsNoLongerLiveIsLeftOutOfTheTable() async throws {
    let (harness, first, second) = try harnessWithTwoTabs()
    harness.model.liveSessionIDs.subtract(first.sessionIDs)
    harness.model.enableDebugTools()

    await harness.model.takeDebugSample()

    #expect(harness.model.debugMemoryTable.tabs.map(\.id) == [second.id])
  }

  @Test func tabsAreListedHeaviestFirst() async throws {
    let (harness, lighter, heavier) = try harnessWithTwoTabs()
    placeTree(of: 10, in: lighter, harness)
    placeTree(of: 20, in: heavier, harness)
    harness.model.enableDebugTools(
      scan: .sample(appMemory: 400, trees: [(10, [10]), (20, [20, 21])]))

    await harness.model.takeDebugSample()

    #expect(harness.model.debugMemoryTable.tabs.map(\.id) == [heavier.id, lighter.id])
  }

  @Test func tabsHoldingTheSameMemoryAreListedByTitle() async throws {
    let (harness, first, second) = try harnessWithTwoTabs()
    harness.model.renameTab(first.id, to: "Beta")
    harness.model.renameTab(second.id, to: "Alpha")
    placeTree(of: 10, in: first, harness)
    placeTree(of: 20, in: second, harness)
    harness.model.enableDebugTools(
      scan: .sample(appMemory: 400, trees: [(10, [10]), (20, [20])]))

    await harness.model.takeDebugSample()

    #expect(harness.model.debugMemoryTable.tabs.map(\.title) == ["Alpha", "Beta"])
  }
}
