import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct PaneProcessAttributionTests {
  @Test func aPaneTakesTheTreeOnItsTerminalElseTheOneRunningItsForegroundProcess() {
    let byTerminal = TerminalSession.ID()
    let byForeground = TerminalSession.ID()
    let unplaced = TerminalSession.ID()
    let attribution = PaneProcessAttribution(
      trees: [
        .sample(root: 10, pids: [11, 12], device: 4),
        .sample(root: 20, pids: [21, 22], device: 5),
        .sample(root: 30, pids: [30], device: nil),
      ],
      terminalDevices: [byTerminal: 4, unplaced: 9],
      foregroundPIDs: [byForeground: 22],
    )

    #expect(attribution.processesBySession[byTerminal]?.map(\.pid) == [11, 12])
    #expect(attribution.processesBySession[byForeground]?.map(\.pid) == [21, 22])
    #expect(attribution.processesBySession[unplaced] == nil)
    #expect(attribution.unattributedProcesses.map(\.pid) == [30])
  }

  @Test func aTreeGoesToOnePaneEvenWhereTwoNameIt() {
    let first = TerminalSession.ID()
    let second = TerminalSession.ID()
    let attribution = PaneProcessAttribution(
      trees: [.sample(root: 10, pids: [11], device: 4)],
      terminalDevices: [first: 4, second: 4],
      foregroundPIDs: [:],
    )

    #expect(attribution.processesBySession.count == 1)
    #expect(attribution.unattributedProcesses.isEmpty)
  }
}
