import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeStatusBadgeTests {
  @Test func onlyAStatusWithChangesOrUnsyncedCommitsIsBadged() {
    var changed = WorktreeStatus()
    changed.changedFiles = 1
    var behind = WorktreeStatus()
    behind.behind = 2

    #expect(WorktreeStatus.badged(nil) == nil, "not read yet")
    #expect(WorktreeStatus.badged(WorktreeStatus()) == nil, "clean and in sync")
    #expect(WorktreeStatus.badged(changed) == changed)
    #expect(WorktreeStatus.badged(behind) == behind)
  }
}
