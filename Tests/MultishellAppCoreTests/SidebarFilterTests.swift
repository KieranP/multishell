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

  /// Branch and directory names are not the reader's language, so folding
  /// them by the reader's alphabet drops a row they can see on screen.
  @Test func theFilterDoesNotFoldBySomebodyElsesAlphabet() {
    let turkish = Locale(identifier: "tr_TR")
    #expect(
      "kieran/rate-limits".range(of: "LIMITS", options: [.caseInsensitive], locale: turkish) == nil,
      "the dotless I is what breaks it; this is the form that must not be used")

    let entries = SidebarFilter("LIMITS").apply(to: workspace)
    #expect(entries.map(\.project.name) == ["acme-api"])
    #expect(entries.first?.worktrees.map(\.name) == ["kieran/rate-limits"])
    #expect("Crème".foldedContains("creme"), "accents still fold")
  }

  /// Locale.current cannot be moved for one test without moving it for every
  /// suite running beside it, so the guard is on the source instead.
  @Test func theFilterNeverReachesForTheLocaleSensitiveForm() throws {
    let file = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/MultishellAppCore/SidebarFilter.swift")
    let text = try String(contentsOf: file, encoding: .utf8)
    let matching = text.split(whereSeparator: \.isNewline).filter {
      $0.contains("localizedStandardContains") || $0.contains("localizedCaseInsensitiveContains")
    }
    #expect(matching.isEmpty, "folds by the reader's locale: \(matching)")
    #expect(text.contains("foldedContains"), "does not match at all")
  }

  @Test func aBranchSharedByBothProjectsShowsBoth() {
    let entries = SidebarFilter("main").apply(to: workspace)
    #expect(entries.count == 2)
    #expect(entries.allSatisfy { $0.worktrees.map(\.name) == ["main"] })
  }

  /// A renamed worktree is findable by the name the user typed and by the
  /// branch it still is.
  @Test func aRenamedWorktreeMatchesOnEitherName() {
    var ws = workspace
    ws.worktreeNames[ws.worktrees[1].id] = "Checkout flow"

    let byName = SidebarFilter("checkout FLOW").apply(to: ws)
    #expect(byName.map(\.project.name) == ["acme-web"])
    #expect(byName[0].worktrees.map(\.name) == ["feat/checkout"])

    let byBranch = SidebarFilter("feat/").apply(to: ws)
    #expect(byBranch[0].worktrees.map(\.name) == ["feat/checkout"])
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
