import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextSidebarTests {
  private let feature = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"), projectID: "/r", head: "abc", branch: "feat")

  @Test func aWorktreeRowReadsEverythingItsGlyphsMean() {
    var status = WorktreeStatus()
    status.unstaged = 2
    status.changedFiles = 2
    status.ahead = 1
    #expect(
      AccessibilityText.worktree(
        feature, state: .running, status: status, operation: nil, terminalCount: 3,
        isSelected: true)
        == "feat, linked worktree, selected, Working, +0 −0 · 2 modified · ↑1, 3 terminals")
    #expect(
      AccessibilityText.worktree(
        feature, state: nil, status: WorktreeStatus(), operation: nil, terminalCount: 0,
        isSelected: false) == "feat, linked worktree, Nothing running")
    let failed = WorktreeOperation(.postCreateHook, failure: "npm ERR!")
    #expect(
      AccessibilityText.worktree(
        feature, state: nil, status: nil, operation: failed, terminalCount: 0, isSelected: false
      )
      .contains("failed: The post-create hook failed"))
  }

  /// The green glyph is read only where it is drawn, so work that is only in this worktree
  /// silences it here too.
  @Test func aMergedRowSaysSoBetweenItsLockAndItsChanges() {
    var behind = WorktreeStatus()
    behind.behind = 2
    #expect(
      AccessibilityText.worktree(
        feature, state: nil, status: behind, operation: nil, terminalCount: 0, isSelected: false,
        mergeState: .merged(.ancestor, into: "origin/main"))
        == "feat, linked worktree, Nothing running, Merged into origin/main, ↓2")

    var dirty = WorktreeStatus()
    dirty.untracked = 1
    dirty.changedFiles = 1
    #expect(
      !AccessibilityText.worktree(
        feature, state: nil, status: dirty, operation: nil, terminalCount: 0, isSelected: false,
        mergeState: .merged(.ancestor, into: "origin/main")
      ).contains("Merged"))
    #expect(
      !AccessibilityText.worktree(
        feature, state: nil, status: nil, operation: nil, terminalCount: 0, isSelected: false,
        mergeState: .unmerged
      ).contains("Merged"))
  }

  @Test func aRenamedRowReadsItsNameThenItsBranch() {
    let feature = Worktree(
      path: URL(fileURLWithPath: "/w/feat"), projectID: "/w", head: "abc", branch: "feat")
    #expect(
      AccessibilityText.worktree(
        feature, customName: "Checkout flow", state: nil, status: nil, operation: nil,
        terminalCount: 0, isSelected: false)
        == "Checkout flow, linked worktree, branch feat, Nothing running")
  }

  @Test func aProjectRowSaysWhetherItIsExpandedReachableAndFetching() {
    #expect(
      AccessibilityText.project(
        name: "acme", isExpanded: false, isMissing: true, state: .attention, worktreeCount: 1)
        == "acme, project, collapsed, 1 worktree, not reachable, Waiting for input")
    #expect(
      AccessibilityText.project(
        name: "acme", isExpanded: true, isMissing: false, state: nil, worktreeCount: 4)
        == "acme, project, expanded, 4 worktrees")
    #expect(
      AccessibilityText.project(
        name: "acme", isExpanded: true, isMissing: false, state: nil, worktreeCount: 4,
        isFetching: true) == "acme, project, expanded, 4 worktrees, fetching")
  }
}
