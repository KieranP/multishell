import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugMemoryTableTests {
  private let location = DebugLocation(projectName: "acme", worktreeName: "main")

  private func tab(_ title: String, _ processes: [ProcessUsage]) -> DebugTabMemory {
    DebugTabMemory(id: UUID(), title: title, location: location, processes: processes)
  }

  @Test func theAppComesFirstThenTheTabsThenOtherProcessesAndTheTotalLast() {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Claude", [.sample(pid: 10, footprint: 800)]), tab("Shell", [.sample(pid: 20)])],
      unattributedProcesses: [.sample(pid: 30, footprint: 50)])

    #expect(
      table.rows.map(\.title) == [
        "Multishell", "Claude", "Shell", "Other processes", "Total, app and child processes",
      ])
    #expect(table.rows.map(\.totalMemory) == [400, 800, 100, 50, 1_350])
    #expect(table.rows.map(\.barFraction) == [0.5, 1, 0.125, 0.0625, 0])
  }

  @Test func otherProcessesAreLeftOutWhereEveryChildIsATabs() {
    let table = DebugMemoryTable(
      appMemory: 400, tabs: [tab("Shell", [.sample(pid: 20)])], unattributedProcesses: [])
    #expect(!table.rows.contains { $0.source == .unattributed })
  }

  @Test func aTabTheEngineCouldNotPlaceShowsNoMemoryRatherThanZero() throws {
    let table = DebugMemoryTable(
      appMemory: 400, tabs: [tab("Shell", [])], unattributedProcesses: [])
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.processCount == nil)
    #expect(row.totalMemory == nil)
    #expect(row.totalMemoryText == "–")
    #expect(row.disclosure(isExpanded: true) == .notExpandable)
  }

  @Test func aRowWithProcessesOpensToListThem() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20), .sample(pid: 21, parentPID: 20)])],
      unattributedProcesses: [])
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.processRows.map(\.depth) == [0, 1])
    #expect(row.disclosure(isExpanded: false) == .collapsed)
    #expect(row.disclosure(isExpanded: true) == .expanded)
    #expect(table.rows.first?.disclosure(isExpanded: true) == .notExpandable, "the app")
  }
}
