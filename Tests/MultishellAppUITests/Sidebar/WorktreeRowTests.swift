import Foundation
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

  private func row(
    status: WorktreeStatus? = nil,
    autoRename: AutoRenameState? = nil,
    services: WorktreeServices = .empty,
    beginRename: @escaping () -> Void = {},
  ) -> WorktreeRow {
    let worktree = Worktree(
      path: URL(fileURLWithPath: "/w/t/feat"),
      projectID: project.id,
      head: "0",
      branch: "feat",
    )
    return WorktreeRow(
      worktree: worktree,
      customName: nil,
      isRenaming: false,
      terminalCount: 1,
      state: nil,
      operation: nil,
      autoRename: autoRename,
      isSelected: false,
      isDropTarget: false,
      status: status,
      standing: BranchStanding(mergeState: .unknown, services: services),
      theme: .multishellDark,
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
}
