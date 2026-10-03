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
      table.lines.map(\.title) == [
        "Multishell", "Claude", "Shell", "Other processes", "Total, app and child processes",
      ])
    #expect(table.lines.map(\.totalMemory) == [400, 800, 100, 50, 1_350])
    #expect(table.lines.map(\.barFraction) == [0.5, 1, 0.125, 0.0625, 0])
  }

  @Test func otherProcessesAreLeftOutWhereEveryChildIsATabs() {
    let table = DebugMemoryTable(
      appMemory: 400, tabs: [tab("Shell", [.sample(pid: 20)])], unattributedProcesses: [])
    #expect(!table.lines.contains { $0.source == .unattributed })
  }

  @Test func aTabTheEngineCouldNotPlaceShowsNoMemoryRatherThanZero() throws {
    let table = DebugMemoryTable(
      appMemory: 400, tabs: [tab("Shell", [])], unattributedProcesses: [])
    let line = try #require(table.lines.first { $0.title == "Shell" })

    #expect(line.processCount == nil)
    #expect(line.totalMemory == nil)
    #expect(line.totalMemoryText == "–")
    #expect(line.disclosure(isExpanded: true) == .notExpandable)
  }

  @Test func aRowWithProcessesOpensToListThem() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20), .sample(pid: 21, parentPID: 20)])],
      unattributedProcesses: [])
    let line = try #require(table.lines.first { $0.title == "Shell" })

    #expect(line.processLines.map(\.depth) == [0, 1])
    #expect(line.disclosure(isExpanded: false) == .collapsed)
    #expect(line.disclosure(isExpanded: true) == .expanded)
    #expect(table.lines.first?.disclosure(isExpanded: true) == .notExpandable, "the app")
  }
}
