import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlViewsTests {
  @Test func theBoardAndItsShowAllTerminalsOpenAndCloseAsTheirMenuItemsDo() async {
    let harness = Harness()

    #expect(await harness.messageSource.ask(.showView(.agentBoard, project: nil)) == .done)
    #expect(harness.model.showsAgentBoard)
    #expect(await harness.messageSource.ask(.showView(.allTerminals, project: nil)) == .done)
    #expect(harness.model.showsAllTerminals)

    #expect(await harness.messageSource.ask(.hideView(.allTerminals)) == .done)
    #expect(!harness.model.showsAllTerminals)
    #expect(await harness.messageSource.ask(.hideView(.agentBoard)) == .done)
    #expect(!harness.model.showsAgentBoard)
  }

  @Test func bothSettingsWordsOpenTheOneWindowEachOnItsOwnScope() async {
    let harness = Harness()

    _ = await harness.messageSource.ask(
      .showView(.projectSettings, project: ControlID.project(harness.project.id))
    )
    #expect(harness.model.settingsLocation.scope == .project(harness.project.id))
    _ = await harness.messageSource.ask(.showView(.settings, project: nil))
    #expect(harness.model.settingsLocation.scope == .allProjects)

    #expect(harness.platform.shownWindows == [.settings, .settings])
  }

  @Test func projectSettingsWithNoProjectNamedKeepsTheOneShownElseTakesTheSelections() async {
    let harness = Harness()
    let other = Scratch.path("control-views")
    defer { Scratch.remove(other) }
    let second = harness.store.addProject(at: other)
    harness.model.select(harness.main)

    _ = await harness.messageSource.ask(.showView(.projectSettings, project: nil))
    #expect(harness.model.settingsLocation.scope == .project(harness.project.id))

    harness.model.setSettingsScope(.project(second.id))
    _ = await harness.messageSource.ask(.showView(.projectSettings, project: nil))
    #expect(harness.model.settingsLocation.scope == .project(second.id))
  }

  @Test func projectSettingsNamingTheProjectShownOpensItsFirstPageAsTheMenuItemDoes() async {
    let harness = Harness()
    harness.model.showSettings(.hooksDelete, in: .project(harness.project.id))

    _ = await harness.messageSource.ask(
      .showView(.projectSettings, project: ControlID.project(harness.project.id))
    )

    #expect(harness.model.settingsLocation.section == .general)
  }

  @Test func hidingProjectSettingsClosesTheWindowOnlyWhileItShowsAProject() async {
    let harness = Harness()

    _ = await harness.messageSource.ask(.hideView(.projectSettings))
    #expect(harness.platform.closedWindows.isEmpty, "All Projects is shown")

    harness.model.showSettings(of: harness.project)
    _ = await harness.messageSource.ask(.hideView(.projectSettings))
    _ = await harness.messageSource.ask(.hideView(.settings))
    #expect(harness.platform.closedWindows == [.settings, .settings])
  }

  @Test func projectSettingsForAnIDNoProjectHasIsRefusedAndOpensNothing() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.showView(.projectSettings, project: "p-00000000"))
        == .refused(.noProject(id: "p-00000000"))
    )
    #expect(harness.platform.shownWindows.isEmpty)
  }

  @Test func aSettingsPageOpensInTheScopeAskedForAndOneItLacksIsRefusedLeavingTheWindow() async {
    let harness = Harness()
    let project = ControlID.project(harness.project.id)

    #expect(
      await harness.messageSource.ask(
        .showSettingsPage(.hooksDelete, inProject: true, project: project)
      ) == .done
    )
    #expect(
      harness.model.settingsLocation
        == SettingsLocation(scope: .project(harness.project.id), section: .hooksDelete)
    )
    #expect(
      await harness.messageSource.ask(
        .showSettingsPage(.hooksCreate, inProject: false, project: nil)
      )
        == .refused(
          .noSettingsPage(
            .hooksCreate,
            pages: [
              .general, .worktrees, .terminal, .agents, .agentSettings, .agentHooks,
              .notifications, .appearance,
            ],
          )
        )
    )
    #expect(harness.model.settingsLocation.section == .hooksDelete, "the refusal moved nothing")
    #expect(harness.platform.shownWindows == [.settings])
  }

  @Test func aSplitPageNamedWholeOpensItsFirstPartAsItsSidebarRowDoes() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.showSettingsPage(.agents, inProject: false, project: nil))
        == .done
    )

    #expect(harness.model.settingsLocation.section == .agentSettings)
  }

  @Test func aPartOfAnotherScopesSplitPageIsRefusedRatherThanOpenedAsItsPage() async {
    let harness = Harness()
    let project = ControlID.project(harness.project.id)

    let reply = await harness.messageSource.ask(
      .showSettingsPage(.agentHooks, inProject: true, project: project)
    )

    #expect(
      reply
        == .refused(
          .noSettingsPage(
            .agentHooks,
            pages: [
              .general, .worktrees, .hooksCreate, .hooksDelete, .hooksEnvironment, .terminal,
              .agents, .integrations,
            ],
          )
        )
    )
    #expect(harness.model.settingsLocation == .start)
    #expect(harness.platform.shownWindows.isEmpty)
  }

  @Test func projectSettingsWithNoProjectNamedOrSelectedOpensTheOnlyProject() async {
    let harness = Harness()

    _ = await harness.messageSource.ask(.showView(.projectSettings, project: nil))

    #expect(harness.model.settingsLocation.scope == .project(harness.project.id))
  }

  @Test func projectSettingsWithNoProjectNamedOrSelectedIsRefusedAndOpensNothing() async {
    let harness = Harness()
    let other = Scratch.path("control-views-none")
    defer { Scratch.remove(other) }
    harness.store.addProject(at: other)

    #expect(
      await harness.messageSource.ask(.showView(.projectSettings, project: nil))
        == .refused(.noProjectChosen)
    )
    #expect(harness.platform.shownWindows.isEmpty)
  }

  @Test func aPageAskedForEmptiesASearchThatMayHideItsSidebarRow() async {
    let harness = Harness()
    harness.model.setSettingsSearchText("port")

    _ = await harness.messageSource.ask(
      .showSettingsPage(.appearance, inProject: false, project: nil)
    )

    #expect(harness.model.settingsSearchText.isEmpty)
  }

  @Test func movingTheWindowToAProjectEmptiesASearchItsPagesMayNotMatch() async {
    let harness = Harness()
    harness.model.setSettingsSearchText("notif")

    _ = await harness.messageSource.ask(
      .showView(.projectSettings, project: ControlID.project(harness.project.id))
    )

    #expect(harness.model.settingsSearchText.isEmpty)
  }
}
