import Foundation
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct WorktreeRowTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let metrics = UIMetrics(fontSize: 13)

  private func row(
    status: WorktreeStatus? = nil, beginRename: @escaping () -> Void = {}
  ) -> WorktreeRow {
    WorktreeRow(
      worktree: Worktree(
        path: URL(fileURLWithPath: "/w/t/feat"), projectID: project.id, head: "0",
        branch: "feat"),
      customName: nil, isRenaming: false, terminalCount: 1, state: nil, operation: nil,
      isSelected: false, isDropTarget: false, status: status, mergeState: .unknown,
      theme: .multishellDark, metrics: metrics, beginRename: beginRename, commitRename: { _ in },
      cancelRename: {})
  }

  @Test func aWorktreeRowRebuiltWithFreshClosuresIsTheSameRow() {
    #expect(row() == row(beginRename: { print("another") }))
  }

  @Test func aWorktreeRowWhoseStatusChangedIsNot() {
    var dirty = WorktreeStatus()
    dirty.changedFiles = 1
    #expect(row() != row(status: dirty))
  }
}
