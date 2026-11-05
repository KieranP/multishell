import AppKit
import Foundation
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite @MainActor
struct WorktreeRowTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let metrics = UIMetrics(fontSize: 13, fontFamily: nil)

  private var changedStatus: WorktreeStatus {
    var status = WorktreeStatus()
    status.changedFiles = 3
    status.insertions = 10
    status.deletions = 1
    return status
  }

  private func row(
    branch: String = "feat",
    terminalCount: Int = 1,
    state: SessionState? = nil,
    status: WorktreeStatus? = nil,
    autoRename: AutoRenameState? = nil,
    services: WorktreeServices = .empty,
    theme: Theme = .multishellDark,
    beginRename: @escaping () -> Void = {},
  ) -> WorktreeRow {
    let worktree = Worktree(
      path: URL(fileURLWithPath: "/w/t/feat"),
      projectID: project.id,
      head: "0",
      branch: branch,
    )
    return WorktreeRow(
      worktree: worktree,
      customName: nil,
      isRenaming: false,
      terminalCount: terminalCount,
      state: state,
      operation: nil,
      autoRename: autoRename,
      isSelected: false,
      isDropTarget: false,
      status: status,
      standing: BranchStanding(mergeState: .unknown, services: services),
      theme: theme,
      metrics: metrics,
      beginRename: beginRename,
      commitRename: { _ in },
      cancelRename: {},
      showModifiedFiles: {},
      clearAutoRenameFailure: {},
      showPullRequest: {},
      showCIRuns: {},
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

  @Test func aWorktreeRowWhoseServicesChangedIsADifferentRow() {
    let running = WorktreeServices(
      upstream: BranchUpstream(remote: "origin", branch: "feat", tip: "0"),
      localTip: "0",
      localBranch: "feat",
      pullRequests: nil,
      ciRuns: ProjectCIRuns(
        integration: .circleCI,
        runsByBranch: [
          "feat": CIRun(
            id: "r",
            branch: "feat",
            commit: "0",
            subject: nil,
            status: .running,
            isFinished: false,
            createdAt: nil,
          )
        ],
      ),
    )
    #expect(row() != row(services: running))
  }

  @Test func aWorktreeRowWhoseAutoRenameMovedIsADifferentRow() {
    #expect(row() != row(autoRename: .running))
    #expect(row(autoRename: .running) != row(autoRename: .failed("Not signed in")))
  }

  private func pixels(of row: WorktreeRow, width: Double) throws -> NSBitmapImageRep {
    let height = metrics.worktreeRowHeight(hasCustomName: false, isRenaming: false)
    return try #require(
      OffscreenWindow.pixels(ofHosted: row, size: CGSize(width: width, height: height))
    )
  }

  @Test func theTerminalCountKeepsItsHeightInANarrowRow() throws {
    let theme = try MagentaTheme.with([.projectsPanel: [.fill]])
    let crowdedRow = row(
      branch: "feature/a-long-branch-name",
      terminalCount: 4,
      state: .done,
      status: changedStatus,
      theme: theme,
    )

    let narrow = MagentaTheme.inkedRowCount(in: try pixels(of: crowdedRow, width: 160))
    let wide = MagentaTheme.inkedRowCount(in: try pixels(of: crowdedRow, width: 400))

    #expect(wide > 0)
    #expect(narrow == wide)
  }
}
