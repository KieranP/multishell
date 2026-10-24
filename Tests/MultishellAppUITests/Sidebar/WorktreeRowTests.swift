import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore
@testable import MultishellGitKit

@Suite @MainActor
struct WorktreeRowTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let metrics = UIMetrics(fontSize: 13, fontFamily: nil)

  private func row(
    status: WorktreeStatus? = nil,
    autoRename: AutoRenameState? = nil,
    beginRename: @escaping () -> Void = {},
  ) -> WorktreeRow {
    WorktreeRow(
      worktree: Worktree(
        path: URL(fileURLWithPath: "/w/t/feat"),
        projectID: project.id,
        head: "0",
        branch: "feat",
      ),
      customName: nil,
      isRenaming: false,
      terminalCount: 1,
      state: nil,
      operation: nil,
      autoRename: autoRename,
      isSelected: false,
      isDropTarget: false,
      status: status,
      mergeState: .unknown,
      theme: .multishellDark,
      metrics: metrics,
      beginRename: beginRename,
      commitRename: { _ in },
      cancelRename: {},
      showModifiedFiles: {},
      clearAutoRenameFailure: {},
    )
  }

  @Test func aWorktreeRowRebuiltWithFreshClosuresIsTheSameRow() {
    #expect(row() == row(beginRename: { print("another") }))
  }

  @Test func aWorktreeRowWhoseStatusChangedIsADifferentRow() {
    var dirty = WorktreeStatus()
    dirty.changedFiles = 1
    #expect(row() != row(status: dirty))
  }

  @Test func aWorktreeRowWhoseAutoRenameMovedIsADifferentRow() {
    #expect(row() != row(autoRename: .running))
    #expect(row(autoRename: .running) != row(autoRename: .failed("Not signed in")))
  }
}
