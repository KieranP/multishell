import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

struct WorktreeStatusUnfinishedUpdateTests {
  @Test func aStopWithConflictsCountsThemAndPointsAtTheMenu() {
    var status = WorktreeStatus()
    status.unfinishedUpdate = .rebase
    status.conflicted = 2

    #expect(status.unfinishedUpdateText == "Rebasing · 2 conflicts")
    #expect(status.unfinishedUpdateHelp?.hasPrefix("Stopped on conflicts.") == true)
  }

  @Test func aStopWithNothingUnmergedNamesItsContinueCommand() {
    var status = WorktreeStatus()
    status.unfinishedUpdate = .merge

    #expect(status.unfinishedUpdateText == "Merging")
    #expect(status.unfinishedUpdateHelp?.contains("git merge --continue") == true)
    #expect(status.unfinishedUpdateHelp?.contains("conflicts") == false)
  }

  @Test func aStatusWithNoStopSaysNothing() {
    #expect(WorktreeStatus().unfinishedUpdateText == nil)
    #expect(WorktreeStatus().unfinishedUpdateHelp == nil)
  }
}
