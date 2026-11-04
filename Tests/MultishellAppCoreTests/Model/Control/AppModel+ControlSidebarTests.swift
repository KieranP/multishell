import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlSidebarTests {
  @Test func theSidebarIsListedAsDrawnByProjectAndWorktreeIDWithPaneRowsInView() async throws {
    let harness = Harness()
    harness.model.select(harness.main)

    let reply = try #require(await harness.messageSource.ask(.listSidebar))

    let projects = try #require(reply.outputFields["projects"] as? [[String: Any]])
    #expect(projects.compactMap { $0["id"] as? String } == [ControlID.project(harness.project.id)])
    let worktrees = try #require(projects.first?["worktrees"] as? [[String: Any]])
    #expect(
      Set(worktrees.compactMap { $0["id"] as? String })
        == [ControlID.worktree(harness.main.id), ControlID.worktree(harness.feature.id)]
    )
    let inView = try #require(worktrees.first { $0["isInView"] as? Bool == true })
    #expect((inView["panes"] as? [[String: Any]])?.count == 1)
    #expect(inView["terminalCount"] as? Int == 1)
  }

  @Test func aFilterNarrowsTheRowsAndACollapsedProjectListsNone() async throws {
    let harness = Harness()
    harness.model.sidebarFilterText = "feature"

    let filtered = try #require(await harness.messageSource.ask(.listSidebar))
    let projects = try #require(filtered.outputFields["projects"] as? [[String: Any]])
    let worktrees = try #require(projects.first?["worktrees"] as? [[String: Any]])
    #expect(
      worktrees.compactMap { $0["id"] as? String } == [ControlID.worktree(harness.feature.id)]
    )
    #expect(filtered.outputFields["filterText"] as? String == "feature")

    harness.model.sidebarFilterText = ""
    harness.model.toggleExpansion(of: harness.project)
    let collapsed = try #require(await harness.messageSource.ask(.listSidebar))
    let rows = try #require(collapsed.outputFields["projects"] as? [[String: Any]])
    #expect(rows.first?["isExpanded"] as? Bool == false)
    #expect((rows.first?["worktrees"] as? [Any])?.isEmpty == true)
  }

  @Test func theSidebarFilterTakesTextAndEmptyPutsTheFieldAway() async {
    let harness = Harness()

    _ = await harness.messageSource.ask(.filterSidebar(text: "feat"))
    #expect(harness.model.sidebarFilterText == "feat")
    #expect(harness.model.showsSidebarFilter)

    _ = await harness.messageSource.ask(.filterSidebar(text: ""))
    #expect(harness.model.sidebarFilterText.isEmpty)
    #expect(!harness.model.showsSidebarFilter)
  }

  @Test func hiddenRowsAreCountedAndListedOnlyOnceTheirSectionIsExpanded() async throws {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)

    let closed = try #require(await harness.messageSource.ask(.listSidebar))
    let closedProject = try #require((closed.outputFields["projects"] as? [[String: Any]])?.first)
    let shown = try #require(closedProject["worktrees"] as? [[String: Any]])
    #expect(shown.compactMap { $0["id"] as? String } == [ControlID.worktree(harness.main.id)])
    #expect(closedProject["hiddenWorktreeCount"] as? Int == 1)
    #expect(closedProject["isHiddenSectionExpanded"] as? Bool == false)
    #expect((closedProject["hiddenWorktrees"] as? [Any])?.isEmpty == true)

    harness.model.toggleHiddenSectionExpansion(of: harness.project)
    let open = try #require(await harness.messageSource.ask(.listSidebar))
    let openProject = try #require((open.outputFields["projects"] as? [[String: Any]])?.first)
    let hidden = try #require(openProject["hiddenWorktrees"] as? [[String: Any]])
    #expect(hidden.compactMap { $0["id"] as? String } == [ControlID.worktree(harness.feature.id)])
  }

  @Test func aCollapsedProjectListsNoHiddenRowsThoughItsSectionIsExpanded() async throws {
    let harness = Harness()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.toggleHiddenSectionExpansion(of: harness.project)
    harness.model.setExpanded(false, for: harness.project)

    let reply = try #require(await harness.messageSource.ask(.listSidebar))

    let project = try #require((reply.outputFields["projects"] as? [[String: Any]])?.first)
    #expect((project["hiddenWorktrees"] as? [Any])?.isEmpty == true)
    #expect(project["hiddenWorktreeCount"] as? Int == 1)
  }
}
