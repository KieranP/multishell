import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite
struct AccessibilityTextSidebarTests {
  private let feature = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"),
    projectID: "/r",
    head: "abc",
    branch: "feat",
  )

  private var mergedPullRequestAndFailedRun: WorktreeServices {
    WorktreeServices(
      upstream: BranchUpstream(remote: "origin", branch: "feat", tip: "tip"),
      localTip: "tip",
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: [.sample(number: 9, state: .merged, headCommit: "tip")],
        remotes: [GitRemote(name: "origin", url: "git@github.com:me/demo.git")],
      ),
      ciRuns: ProjectCIRuns(
        integration: .circleCI,
        runsByBranch: ["feat": .sample(status: .failed)],
      ),
    )
  }

  @Test func aWorktreeRowSaysAnAutoRenameIsRunningOrHasFailed() {
    let spoken = { (autoRename: AutoRenameState) in
      AccessibilityText.worktree(
        feature,
        state: nil,
        status: nil,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(mergeState: .unknown, services: .empty),
        autoRename: autoRename,
      )
    }
    #expect(spoken(.running) == "feat, linked worktree, Nothing running, Auto Rename running")
    #expect(
      spoken(.failed("Claude Code said: Not logged in"))
        == "feat, linked worktree, Nothing running, Auto Rename failed",
      "the reason is the row's hint, not read on every visit",
    )
  }

  @Test func aFailedAutoRenamesReasonIsTheRowsHint() {
    #expect(AccessibilityText.worktreeHint(autoRename: .failed("Not logged in")) == "Not logged in")
    #expect(AccessibilityText.worktreeHint(autoRename: .running) == "")
    #expect(AccessibilityText.worktreeHint(autoRename: nil) == "")
  }

  @Test func aWorktreeRowReadsEverythingItsGlyphsMean() {
    var status = WorktreeStatus()
    status.unstaged = 2
    status.changedFiles = 2
    status.ahead = 1
    #expect(
      AccessibilityText.worktree(
        feature,
        state: .running,
        status: status,
        operation: nil,
        terminalCount: 3,
        isSelected: true,
        customName: nil,
        standing: BranchStanding(mergeState: .unknown, services: .empty),
        autoRename: nil,
      )
        == "feat, linked worktree, selected, Working, +0 −0 · 2 modified · ↑1, 3 terminals"
    )
    #expect(
      AccessibilityText.worktree(
        feature,
        state: nil,
        status: WorktreeStatus(),
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(mergeState: .unknown, services: .empty),
        autoRename: nil,
      ) == "feat, linked worktree, Nothing running"
    )
    let failed = WorktreeOperation(.postCreateHook, failure: "npm ERR!")
    #expect(
      AccessibilityText.worktree(
        feature,
        state: nil,
        status: nil,
        operation: failed,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(mergeState: .unknown, services: .empty),
        autoRename: nil,
      )
      .contains("failed: The post-create hook failed")
    )
  }

  /// The green glyph is read only where it is drawn, so work that is only in this worktree
  /// silences it here too.
  @Test func aMergedRowSaysSoBetweenItsLockAndItsChanges() {
    let locked = Worktree(
      path: URL(fileURLWithPath: "/trees/feat"),
      projectID: "/r",
      head: "abc",
      branch: "feat",
      isLocked: true,
    )
    var behind = WorktreeStatus()
    behind.behind = 2
    #expect(
      AccessibilityText.worktree(
        locked,
        state: nil,
        status: behind,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(
          mergeState: .merged(.ancestor, into: "origin/main"),
          services: .empty,
        ),
        autoRename: nil,
      )
        == "feat, linked worktree, Nothing running, locked, Merged into origin/main, ↓2"
    )

    var dirty = WorktreeStatus()
    dirty.untracked = 1
    dirty.changedFiles = 1
    #expect(
      !AccessibilityText.worktree(
        feature,
        state: nil,
        status: dirty,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(
          mergeState: .merged(.ancestor, into: "origin/main"),
          services: .empty,
        ),
        autoRename: nil,
      ).contains("Merged")
    )
    #expect(
      !AccessibilityText.worktree(
        feature,
        state: nil,
        status: nil,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(mergeState: .unmerged, services: .empty),
        autoRename: nil,
      ).contains("Merged")
    )
  }

  @Test func aRowReadsItsPullRequestAndRunInsteadOfTheMergedBadge() {
    let services = mergedPullRequestAndFailedRun
    #expect(
      AccessibilityText.worktree(
        feature,
        state: nil,
        status: nil,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(
          mergeState: .merged(.pullRequest(number: 9), into: "main"),
          services: services,
        ),
        autoRename: nil,
      )
        == "feat, linked worktree, Nothing running, pull request 9, Merged into main, CircleCI failed"
    )
  }

  @Test func aRowReadsItsGitChangesBeforeItsPullRequestAsItDrawsThem() {
    var status = WorktreeStatus()
    status.unstaged = 2
    status.changedFiles = 2
    #expect(
      AccessibilityText.worktree(
        feature,
        state: nil,
        status: status,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: nil,
        standing: BranchStanding(mergeState: .unmerged, services: mergedPullRequestAndFailedRun),
        autoRename: nil,
      )
        == "feat, linked worktree, Nothing running, +0 −0 · 2 modified, pull request 9, "
        + "Merged into main, CircleCI failed"
    )
  }

  @Test func aRenamedRowReadsItsNameThenItsBranch() {
    let feature = Worktree(
      path: URL(fileURLWithPath: "/w/feat"),
      projectID: "/w",
      head: "abc",
      branch: "feat",
    )
    #expect(
      AccessibilityText.worktree(
        feature,
        state: nil,
        status: nil,
        operation: nil,
        terminalCount: 0,
        isSelected: false,
        customName: "Checkout flow",
        standing: BranchStanding(mergeState: .unknown, services: .empty),
        autoRename: nil,
      )
        == "Checkout flow, linked worktree, branch feat, Nothing running"
    )
  }

  @Test func aProjectRowSaysWhetherItIsExpandedReachableAndFetching() {
    #expect(
      AccessibilityText.project(
        name: "acme",
        isExpanded: false,
        isMissing: true,
        state: .attention,
        worktreeCount: 1,
        isFetching: false,
      )
        == "acme, project, collapsed, 1 worktree, not reachable, Waiting for input"
    )
    #expect(
      AccessibilityText.project(
        name: "acme",
        isExpanded: true,
        isMissing: false,
        state: nil,
        worktreeCount: 4,
        isFetching: false,
      )
        == "acme, project, expanded, 4 worktrees"
    )
    #expect(
      AccessibilityText.project(
        name: "acme",
        isExpanded: true,
        isMissing: false,
        state: nil,
        worktreeCount: 4,
        isFetching: true,
      ) == "acme, project, expanded, 4 worktrees, fetching"
    )
  }

  /// A renamed tab names every pane alike, so the position tells them apart.
  @Test func aPaneInARenamedTabSaysItsPosition() {
    let pane = SidebarPane(
      id: UUID(),
      title: "fix tests",
      position: PanePosition(number: 2, count: 2),
      isFocused: true,
      state: nil,
      workers: [],
      agentID: nil,
      agentName: nil,
    )
    #expect(AccessibilityText.pane(pane) == "fix tests, pane 2 of 2, selected")
  }
}
