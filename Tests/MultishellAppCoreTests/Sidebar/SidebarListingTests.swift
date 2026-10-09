import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct SidebarListingTests {
  private var workspace: Workspace {
    var sample = Workspace()
    let web = Project(path: URL(fileURLWithPath: "/w/acme-web"))
    let api = Project(path: URL(fileURLWithPath: "/w/acme-api"))
    sample.projects = [web, api]
    sample.worktrees = [
      Worktree(path: web.path, projectID: web.id, head: "a", branch: "main", isPrimary: true),
      Worktree(
        path: URL(fileURLWithPath: "/w/t/checkout"),
        projectID: web.id,
        head: "b",
        branch: "feat/checkout",
      ),
      Worktree(path: api.path, projectID: api.id, head: "c", branch: "main", isPrimary: true),
      Worktree(
        path: URL(fileURLWithPath: "/w/t/limits"),
        projectID: api.id,
        head: "d",
        branch: "kieran/rate-limits",
      ),
    ]
    return sample
  }

  @Test func noFilterShowsEverythingAsEachProjectIsStored() {
    var sample = workspace
    sample.projects[1].isExpanded = false
    let entries = SidebarListing(filterText: "  ").entries(
      in: sample,
      collapsing: [sample.projects[0].id],
    )
    #expect(entries.map(\.project.name) == ["acme-web", "acme-api"])
    #expect(entries.map(\.isExpanded) == [true, false])
    #expect(entries.allSatisfy { $0.worktrees.count == 2 })
    #expect(!SidebarListing(filterText: "").isFiltering)
  }

  @Test func theFilterHoldsACollapsedProjectOpenUnlessItWasCollapsedUnderIt() {
    var sample = workspace
    sample.projects = sample.projects.map { project in
      var collapsed = project
      collapsed.isExpanded = false
      return collapsed
    }
    let entries = SidebarListing(filterText: "main").entries(
      in: sample,
      collapsing: [sample.projects[1].id],
    )
    #expect(entries.map(\.isExpanded) == [true, false])
  }

  @Test func aProjectNameMatchKeepsAllItsWorktrees() {
    let entries = SidebarListing(filterText: "WEB").entries(in: workspace)
    #expect(entries.count == 1)
    #expect(entries[0].worktrees.map(\.name) == ["main", "feat/checkout"])
    #expect(entries[0].isExpanded)
  }

  @Test func aBranchMatchKeepsOnlyMatchingWorktrees() {
    let entries = SidebarListing(filterText: "rate").entries(in: workspace)
    #expect(entries.map(\.project.name) == ["acme-api"])
    #expect(entries[0].worktrees.map(\.name) == ["kieran/rate-limits"])
    #expect(entries[0].isExpanded)
  }

  @Test func anUppercaseQueryMatchesALowercaseBranch() {
    let entries = SidebarListing(filterText: "LIMITS").entries(in: workspace)
    #expect(entries.map(\.project.name) == ["acme-api"])
    #expect(entries.first?.worktrees.map(\.name) == ["kieran/rate-limits"])
  }

  /// Locale.current cannot be moved for one test without moving it for every
  /// suite running beside it, so the guard is on the source instead.
  @Test func theFilterNeverReachesForTheLocaleSensitiveForm() throws {
    let file = SourceRoot.url.appendingPathComponent(
      "Sources/MultishellAppCore/Sidebar/SidebarListing.swift"
    )
    let text = try String(contentsOf: file, encoding: .utf8)
    let matching = text.split(whereSeparator: \.isNewline).filter { line in
      line.contains("localizedStandardContains")
        || line.contains("localizedCaseInsensitiveContains")
    }
    #expect(matching.isEmpty, "folds by the reader's locale: \(matching)")
    #expect(text.contains("foldedContains"), "does not match at all")
  }

  @Test func aBranchSharedByBothProjectsShowsBoth() {
    let entries = SidebarListing(filterText: "main").entries(in: workspace)
    #expect(entries.count == 2)
    #expect(entries.allSatisfy { $0.worktrees.map(\.name) == ["main"] })
  }

  @Test func aRenamedWorktreeMatchesOnEitherName() {
    var sample = workspace
    sample.customWorktreeNames[sample.worktrees[1].id] = "Checkout flow"

    let byName = SidebarListing(filterText: "checkout FLOW").entries(in: sample)
    #expect(byName.map(\.project.name) == ["acme-web"])
    #expect(byName[0].worktrees.map(\.name) == ["feat/checkout"])

    let byBranch = SidebarListing(filterText: "feat/").entries(in: sample)
    #expect(byBranch[0].worktrees.map(\.name) == ["feat/checkout"])
  }

  @Test func aFilterNothingMatchesShowsNoRows() {
    #expect(SidebarListing(filterText: "zzz").entries(in: workspace).isEmpty)
  }
}
