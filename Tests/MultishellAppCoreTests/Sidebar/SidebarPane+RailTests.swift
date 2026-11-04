import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct SidebarPaneRailTests {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func pane(_ state: SessionState?) -> SidebarPane {
    SidebarPane(
      id: UUID(),
      title: "claude",
      position: nil,
      isFocused: false,
      state: state,
      since: start,
      workers: [],
      agentID: "claude",
      agentName: "Claude Code",
    )
  }

  @Test func aWorkingPaneSaysHowLongItHasWorked() {
    let working = pane(.running)
    #expect(working.railState == .running)
    #expect(working.elapsed(at: start.addingTimeInterval(38)) == "38s")
  }

  @Test func anIdlePaneLeavesTheRailEmpty() {
    let idle = pane(.idle)
    #expect(idle.railState == nil)
    #expect(idle.elapsed(at: start.addingTimeInterval(600)) == nil)
  }

  @Test func aPaneWithNoReportLeavesTheRailEmpty() {
    let unreported = pane(nil)
    #expect(unreported.railState == nil)
    #expect(unreported.elapsed(at: start.addingTimeInterval(600)) == nil)
  }
}
