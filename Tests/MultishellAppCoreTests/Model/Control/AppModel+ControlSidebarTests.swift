import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlSidebarTests {
  @Test func theSidebarIsListedAsDrawnByProjectAndWorktreeIDWithPaneRowsInView() async throws {
    let harness = Harness()
    harness.model.select(harness.main)

    let reply = try #require(await harness.stateSource.ask(.listSidebar))

    let projects = try #require(reply.outputFields["projects"] as? [[String: Any]])
    #expect(projects.compactMap { $0["id"] as? String } == [ControlID.project(harness.project.id)])
    let worktrees = try #require(projects.first?["worktrees"] as? [[String: Any]])
    #expect(
      Set(worktrees.compactMap { $0["id"] as? String })
        == [ControlID.worktree(harness.main.id), ControlID.worktree(harness.feature.id)]
    )
    let inView = try #require(worktrees.first { $0["isInView"] as? Bool == true })
    #expect((inView["panes"] as? [[String: Any]])?.count == 1)
  }

  @Test func aFilterNarrowsTheRowsAndACollapsedProjectListsNone() async throws {
    let harness = Harness()
    harness.model.sidebarFilterText = "feature"

    let filtered = try #require(await harness.stateSource.ask(.listSidebar))
    let projects = try #require(filtered.outputFields["projects"] as? [[String: Any]])
    let worktrees = try #require(projects.first?["worktrees"] as? [[String: Any]])
    #expect(
      worktrees.compactMap { $0["id"] as? String } == [ControlID.worktree(harness.feature.id)]
    )
    #expect(filtered.outputFields["filterText"] as? String == "feature")

    harness.model.sidebarFilterText = ""
    harness.model.toggleExpansion(of: harness.project)
    let collapsed = try #require(await harness.stateSource.ask(.listSidebar))
    let rows = try #require(collapsed.outputFields["projects"] as? [[String: Any]])
    #expect(rows.first?["isExpanded"] as? Bool == false)
    #expect((rows.first?["worktrees"] as? [Any])?.isEmpty == true)
  }
}
