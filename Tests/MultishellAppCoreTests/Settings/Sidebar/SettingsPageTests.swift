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
}
