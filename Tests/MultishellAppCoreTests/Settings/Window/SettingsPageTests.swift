import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SettingsPageTests {
  private static let project = SettingsScope.project("/repo")

  @Test func eachScopeListsItsOwnPagesInTheWindowsOrder() {
    #expect(
      SettingsPage.pages(in: .allProjects)
        == [.general, .worktrees, .terminal, .agents, .notifications, .appearance]
    )
    #expect(
      SettingsPage.pages(in: Self.project)
        == [.general, .worktrees, .hooks, .terminal, .agents, .integrations]
    )
  }

  @Test func everyListedPageHasSomethingToShowAndEveryOtherHasNothing() {
    let pages: [SettingsPage] = [
      .agents, .appearance, .general, .hooks, .integrations, .notifications, .terminal, .worktrees,
    ]
    for scope in [SettingsScope.allProjects, Self.project] {
      let listed = SettingsPage.pages(in: scope)
      for page in pages {
        #expect(page.sections(in: scope).isEmpty != listed.contains(page), "\(page) in \(scope)")
      }
    }
  }

  @Test func onlyAllProjectsAgentsAndAProjectsHooksAreSplitIntoParts() {
    #expect(SettingsPage.agents.sections(in: .allProjects) == [.agentSettings, .agentHooks])
    #expect(SettingsPage.agents.sections(in: Self.project) == [.agents])
    #expect(
      SettingsPage.hooks.sections(in: Self.project)
        == [.hooksCreate, .hooksDelete, .hooksEnvironment]
    )
  }

  @Test func everySectionBelongsToThePageThatListsIt() {
    for scope in [SettingsScope.allProjects, Self.project] {
      for page in SettingsPage.pages(in: scope) {
        for section in page.sections(in: scope) {
          #expect(section.page == page, "\(section) listed under \(page)")
        }
      }
    }
  }

  @Test func onlyThePartsOfASplitPageArePartsAndEveryOneIsListedUnderItsPage() {
    let parts: [SettingsSection] = [
      .agentSettings, .agentHooks, .hooksCreate, .hooksDelete, .hooksEnvironment,
    ]
    for scope in [SettingsScope.allProjects, Self.project] {
      for page in SettingsPage.pages(in: scope) {
        let sections = page.sections(in: scope)
        #expect(sections.allSatisfy { $0.isPart == (sections.count > 1) }, "\(page) in \(scope)")
      }
    }
    #expect(parts.allSatisfy { $0.isPart })
    let listed = [SettingsScope.allProjects, Self.project].flatMap { scope in
      SettingsPage.pages(in: scope).flatMap { $0.sections(in: scope) }
    }
    for part in parts {
      #expect(listed.contains(part), "\(part) has a sidebar row")
    }
  }
}
