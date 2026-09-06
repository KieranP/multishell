import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SidebarFilterTests {
  private var workspace: Workspace {
    var ws = Workspace()
    let web = Project(path: URL(fileURLWithPath: "/w/acme-web"))
    let api = Project(path: URL(fileURLWithPath: "/w/acme-api"))
    ws.projects = [web, api]
    ws.worktrees = [
      Worktree(path: web.path, projectID: web.id, head: "a", branch: "main", isPrimary: true),
      Worktree(
        path: URL(fileURLWithPath: "/w/t/checkout"), projectID: web.id, head: "b",
        branch: "feat/checkout"),
      Worktree(path: api.path, projectID: api.id, head: "c", branch: "main", isPrimary: true),
      Worktree(
        path: URL(fileURLWithPath: "/w/t/limits"), projectID: api.id, head: "d",
        branch: "kieran/rate-limits"),
    ]
    return ws
  }

  @Test func noFilterShowsEverythingUnforced() {
    let entries = SidebarFilter("  ").apply(to: workspace)
    #expect(entries.map(\.project.name) == ["acme-web", "acme-api"])
    #expect(entries.allSatisfy { !$0.forcedOpen && $0.worktrees.count == 2 })
    #expect(!SidebarFilter("").isActive)
  }

  @Test func aProjectNameMatchKeepsAllItsWorktrees() {
    let entries = SidebarFilter("WEB").apply(to: workspace)
    #expect(entries.count == 1)
    #expect(entries[0].worktrees.map(\.name) == ["main", "feat/checkout"])
    #expect(entries[0].forcedOpen)
  }

  @Test func aBranchMatchKeepsOnlyMatchingWorktrees() {
    let entries = SidebarFilter("rate").apply(to: workspace)
    #expect(entries.map(\.project.name) == ["acme-api"])
    #expect(entries[0].worktrees.map(\.name) == ["kieran/rate-limits"])
    #expect(entries[0].forcedOpen)
  }

  @Test func aBranchSharedByBothProjectsShowsBoth() {
    let entries = SidebarFilter("main").apply(to: workspace)
    #expect(entries.count == 2)
    #expect(entries.allSatisfy { $0.worktrees.map(\.name) == ["main"] })
  }

  @Test func noMatchIsEmpty() {
    #expect(SidebarFilter("zzz").apply(to: workspace).isEmpty)
  }
}

@Suite
struct HomeAbbreviationTests {
  @Test func onlyAWholeComponentIsTheHomeDirectory() {
    #expect("/Users/me/Work/x".abbreviatingHomeDirectory(home: "/Users/me") == "~/Work/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me") == "~")
    #expect("/Users/meg/Work".abbreviatingHomeDirectory(home: "/Users/me") == "/Users/meg/Work")
    #expect("/tmp/x".abbreviatingHomeDirectory(home: "/Users/me") == "/tmp/x")
  }
}
