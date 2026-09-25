import Foundation
import MultishellAppCore
import MultishellCore
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct SidebarRowEqualityTests {
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
      theme: .multishellDark, metrics: metrics, beginRename: beginRename, commit: { _ in },
      cancel: {})
  }

  private func projectRow(
    isFetching: Bool = false, toggle: @escaping () -> Void = {}
  )
    -> ProjectRow
  {
    ProjectRow(
      project: project, settings: ProjectSettings(), isMissing: false, state: nil,
      worktreeCount: 2, isFetching: isFetching, theme: .multishellDark, metrics: metrics,
      toggle: toggle, newWorktree: {})
  }

  @Test func aWorktreeRowRebuiltWithFreshClosuresIsTheSameRow() {
    #expect(row() == row(beginRename: { print("another") }))
  }

  @Test func aWorktreeRowWhoseStatusChangedIsNot() {
    var dirty = WorktreeStatus()
    dirty.changedFiles = 1
    #expect(row() != row(status: dirty))
  }

  @Test func aProjectRowRebuiltWithFreshClosuresIsTheSameRowUntilItsStateMoves() {
    #expect(projectRow() == projectRow(toggle: { print("another") }))
    #expect(projectRow() != projectRow(isFetching: true))
  }

  @Test func theAgentsRowComparesItsCounts() {
    let none = AgentsRow(
      counts: [(.waiting, 0)], isSelected: false, theme: .multishellDark, metrics: metrics,
      select: {})
    let one = AgentsRow(
      counts: [(.waiting, 1)], isSelected: false, theme: .multishellDark, metrics: metrics,
      select: {})
    #expect(none == none)
    #expect(none != one)
  }
}
