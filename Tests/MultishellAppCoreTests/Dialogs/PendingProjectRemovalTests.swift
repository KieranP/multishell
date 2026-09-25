import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct PendingProjectRemovalTests {
  @Test func theMessageCountsLiveTerminalsAndSaysTheDiskIsUntouched() {
    let none = PendingProjectRemoval.message(liveTerminals: 0)
    #expect(none.hasPrefix("Takes the project and its worktrees out of the sidebar."))
    #expect(!none.contains("terminal"))
    #expect(none.contains("Nothing on disk is touched"))
    #expect(PendingProjectRemoval.message(liveTerminals: 1).contains("1 open terminal will"))
    #expect(PendingProjectRemoval.message(liveTerminals: 3).contains("3 open terminals will"))
  }

  @Test func eachWindowPresentsOnlyItsOwnRequest() {
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let pending = PendingProjectRemoval(project: project, source: .settings)
    #expect(pending.id == project.id)
    #expect(pending.title == "Remove project demo?")
    #expect(pending.source == .settings && pending.source != .workspace)
  }
}
