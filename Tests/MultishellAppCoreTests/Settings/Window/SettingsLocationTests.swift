import Testing

@testable import MultishellAppCore

@Suite
struct SettingsLocationTests {
  private static let project = SettingsScope.project("/repo")

  @Test func aPageBothScopesHaveIsKeptAcrossAScopeChange() {
    let worktrees = SettingsLocation(scope: Self.project, section: .worktrees)
    #expect(worktrees.moved(to: .allProjects) == .init(scope: .allProjects, section: .worktrees))

    let terminal = SettingsLocation(scope: .allProjects, section: .terminal)
    #expect(terminal.moved(to: Self.project) == .init(scope: Self.project, section: .terminal))
  }

  @Test func aSplitAgentsPageLandsOnItsFirstPartAndEitherPartOnTheWholePage() {
    let agents = SettingsLocation(scope: Self.project, section: .agents)
    #expect(agents.moved(to: .allProjects) == .init(scope: .allProjects, section: .agentSettings))

    let hooks = SettingsLocation(scope: .allProjects, section: .agentHooks)
    #expect(hooks.moved(to: Self.project) == .init(scope: Self.project, section: .agents))
  }

  @Test func aPageTheOtherScopeLacksFallsBackToGeneral() {
    let create = SettingsLocation(scope: Self.project, section: .hooksCreate)
    #expect(create.moved(to: .allProjects) == .start)

    let appearance = SettingsLocation(scope: .allProjects, section: .appearance)
    #expect(appearance.moved(to: Self.project) == .init(scope: Self.project, section: .general))
  }

  @Test func anotherProjectKeepsThePageAndPartShown() {
    let delete = SettingsLocation(scope: Self.project, section: .hooksDelete)
    #expect(
      delete.moved(to: .project("/other"))
        == .init(scope: .project("/other"), section: .hooksDelete)
    )
  }

  @Test func theArrowsStepThroughPagesAndPartsAndStopAtEitherEnd() {
    let general = SettingsLocation(scope: .allProjects, section: .general)
    let pages = SettingsPage.pages(in: .allProjects)
    #expect(general.stepped(by: -1, among: pages) == general)
    #expect(general.stepped(by: 3, among: pages).section == .agentSettings)
    #expect(general.stepped(by: 4, among: pages).section == .agentHooks)
    #expect(general.stepped(by: 99, among: pages).section == .appearance)

    let terminal = SettingsLocation(scope: Self.project, section: .terminal)
    #expect(
      terminal.stepped(by: -1, among: SettingsPage.pages(in: Self.project)).section
        == .hooksEnvironment
    )
  }

  @Test func theArrowsStepOnlyThroughThePagesTheSidebarLists() {
    let appearance = SettingsLocation(scope: .allProjects, section: .appearance)

    #expect(appearance.stepped(by: -1, among: [.general, .appearance]).section == .general)
  }

  @Test func aPageRowIsSelectedOnlyForAWholePageAndNeverForItsParts() {
    #expect(SettingsLocation.start.selects(.general))
    #expect(!SettingsLocation(scope: .allProjects, section: .agentHooks).selects(.agents))
    #expect(SettingsLocation(scope: Self.project, section: .agents).selects(.agents))
  }

  @Test func theArrowsStepOntoTheListedPagesWhenASearchHidesTheSelectedOne() {
    let general = SettingsLocation.start

    #expect(general.stepped(by: 1, among: [.appearance]).section == .appearance)
    #expect(general.stepped(by: -1, among: [.appearance]).section == .appearance)
  }
}
