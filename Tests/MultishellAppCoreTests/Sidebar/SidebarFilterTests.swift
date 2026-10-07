import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct SidebarFilterTests {
  private var workspace: Workspace {
    var sample = Workspace()
    let web = Project(path: URL(fileURLWithPath: "/w/acme-web"))
    let api = Project(path: URL(fileURLWithPath: "/w/acme-api"))
    sample.projects = [web, api]
    sample.worktrees = [
      Worktree(path: web.path, projectID: web.id, head: "a", branch: "main", isPrimary: true),
      Worktree(
        path: URL(fileURLWithPath: "/w/t/checkout"), projectID: web.id, head: "b",
        branch: "feat/checkout"),
      Worktree(path: api.path, projectID: api.id, head: "c", branch: "main", isPrimary: true),
      Worktree(
        path: URL(fileURLWithPath: "/w/t/limits"), projectID: api.id, head: "d",
        branch: "kieran/rate-limits"),
    ]
    return sample
  }

  @Test func noFilterShowsEverythingAsEachProjectIsStored() {
    var sample = workspace
    sample.projects[1].isExpanded = false
    let entries = SidebarFilter("  ").apply(to: sample, collapsing: [sample.projects[0].id])
    #expect(entries.map(\.project.name) == ["acme-web", "acme-api"])
    #expect(entries.map(\.isExpanded) == [true, false])
    #expect(entries.allSatisfy { $0.worktrees.count == 2 })
    #expect(!SidebarFilter("").isFiltering)
  }

  @Test func theFilterHoldsACollapsedProjectOpenUnlessItWasCollapsedUnderIt() {
    var sample = workspace
    sample.projects = sample.projects.map { project in
      var collapsed = project
      collapsed.isExpanded = false
      return collapsed
    }
    let entries = SidebarFilter("main").apply(to: sample, collapsing: [sample.projects[1].id])
    #expect(entries.map(\.isExpanded) == [true, false])
  }

  @Test func aProjectNameMatchKeepsAllItsWorktrees() {
    let entries = SidebarFilter("WEB").apply(to: workspace)
    #expect(entries.count == 1)
    #expect(entries[0].worktrees.map(\.name) == ["main", "feat/checkout"])
    #expect(entries[0].isExpanded)
  }

  @Test func aBranchMatchKeepsOnlyMatchingWorktrees() {
    let entries = SidebarFilter("rate").apply(to: workspace)
    #expect(entries.map(\.project.name) == ["acme-api"])
    #expect(entries[0].worktrees.map(\.name) == ["kieran/rate-limits"])
    #expect(entries[0].isExpanded)
  }

  @Test func anUppercaseQueryMatchesALowercaseBranch() {
    let entries = SidebarFilter("LIMITS").apply(to: workspace)
    #expect(entries.map(\.project.name) == ["acme-api"])
    #expect(entries.first?.worktrees.map(\.name) == ["kieran/rate-limits"])
  }

  /// Locale.current cannot be moved for one test without moving it for every
  /// suite running beside it, so the guard is on the source instead.
  @Test func theFilterNeverReachesForTheLocaleSensitiveForm() throws {
    let file = Checkout.root.appendingPathComponent(
      "Sources/MultishellAppCore/Sidebar/SidebarFilter.swift")
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

  @Test func aRenamedWorktreeMatchesOnEitherName() {
    var sample = workspace
    sample.customWorktreeNames[sample.worktrees[1].id] = "Checkout flow"

    let byName = SidebarFilter("checkout FLOW").apply(to: sample)
    #expect(byName.map(\.project.name) == ["acme-web"])
    #expect(byName[0].worktrees.map(\.name) == ["feat/checkout"])

    let byBranch = SidebarFilter("feat/").apply(to: sample)
    #expect(byBranch[0].worktrees.map(\.name) == ["feat/checkout"])
  }

  @Test func aFilterNothingMatchesShowsNoRows() {
    #expect(SidebarFilter("zzz").apply(to: workspace).isEmpty)
  }
}
