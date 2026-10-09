import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SidebarWorktreeTests {
  private let worktree = Worktree(
    path: URL(fileURLWithPath: "/repo"),
    projectID: "/repo",
    head: "a",
    branch: "main",
    isPrimary: true,
  )

  private func row(panes: [SidebarPane]) -> SidebarWorktree {
    SidebarWorktree(worktree: worktree, customName: nil, isRenaming: false, panes: panes)
  }

  @Test func aRowWithNoPaneRowsShowsItsTerminalCount() {
    #expect(row(panes: []).shownTerminalCount(of: 3) == 3)
  }

  @Test func aRowListingItsPanesShowsNoCount() {
    let pane = SidebarPane(
      id: UUID(),
      title: "zsh",
      position: nil,
      isFocused: true,
      state: nil,
      workers: [],
      agentID: nil,
      agentName: nil,
    )
    #expect(row(panes: [pane]).shownTerminalCount(of: 1) == 0)
  }
}
