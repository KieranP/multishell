import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlViewsTests {
  @Test func theBoardAndItsShowAllTerminalsOpenAndCloseAsTheirMenuItemsDo() async {
    let harness = Harness()

    #expect(await harness.stateSource.ask(.showView(.agentBoard, project: nil)) == .done)
    #expect(harness.model.showsAgentBoard)
    #expect(await harness.stateSource.ask(.showView(.allTerminals, project: nil)) == .done)
    #expect(harness.model.showsAllTerminals)

    #expect(await harness.stateSource.ask(.hideView(.allTerminals)) == .done)
    #expect(!harness.model.showsAllTerminals)
    #expect(await harness.stateSource.ask(.hideView(.agentBoard)) == .done)
    #expect(!harness.model.showsAgentBoard)
  }

  @Test func theSettingsWindowsOpenThroughThePlatformAProjectsNamingIt() async {
    let harness = Harness()

    _ = await harness.stateSource.ask(.showView(.settings, project: nil))
    _ = await harness.stateSource.ask(
      .showView(.projectSettings, project: ControlID.project(harness.project.id))
    )
    _ = await harness.stateSource.ask(.hideView(.settings))

    #expect(harness.platform.shownWindows == [.settings, .projectSettings])
    #expect(harness.platform.closedWindows == [.settings])
    #expect(harness.model.settingsWindowProjectID == harness.project.id)
  }

  @Test func projectSettingsForAnIDNoProjectHasIsRefusedAndOpensNothing() async {
    let harness = Harness()

    #expect(
      await harness.stateSource.ask(.showView(.projectSettings, project: "p-00000000"))
        == .refused(.noProject(id: "p-00000000"))
    )
    #expect(harness.platform.shownWindows.isEmpty)
  }

  @Test func theSidebarFilterTakesTextAndEmptyPutsTheFieldAway() async {
    let harness = Harness()

    _ = await harness.stateSource.ask(.filterSidebar(text: "feat"))
    #expect(harness.model.sidebarFilterText == "feat")
    #expect(harness.model.showsSidebarFilter)

    _ = await harness.stateSource.ask(.filterSidebar(text: ""))
    #expect(harness.model.sidebarFilterText.isEmpty)
    #expect(!harness.model.showsSidebarFilter)
  }

  @Test func theWindowIsSizedAndAClosedOneIsRefused() async {
    let harness = Harness()

    #expect(await harness.stateSource.ask(.resizeWindow(width: 900, height: 600)) == .done)
    #expect(harness.platform.workspaceWindowSize?.width == 900)
    #expect(harness.platform.workspaceWindowSize?.height == 600)

    harness.platform.workspaceWindowSize = nil
    #expect(
      await harness.stateSource.ask(.resizeWindow(width: 900, height: 600)) == .refused(.noWindow)
    )
  }

  @Test func aWindowInFullScreenIsNotSizedAsItWouldShrinkInsideTheScreen() async {
    let harness = Harness()
    harness.platform.workspaceWindowSize = (1_200, 800)
    harness.platform.isWorkspaceWindowFullScreen = true

    #expect(
      await harness.stateSource.ask(.resizeWindow(width: 900, height: 600))
        == .refused(.windowInFullScreen)
    )
    #expect(harness.platform.workspaceWindowSize?.width == 1_200)
  }

  @Test func theWindowGoesIntoFullScreenAndOutAndAClosedOneIsRefused() async {
    let harness = Harness()

    #expect(await harness.stateSource.ask(.setFullScreen(on: true)) == .done)
    #expect(harness.platform.isWorkspaceWindowFullScreen)
    #expect(await harness.stateSource.ask(.setFullScreen(on: false)) == .done)
    #expect(!harness.platform.isWorkspaceWindowFullScreen)

    harness.platform.workspaceWindowSize = nil
    #expect(await harness.stateSource.ask(.setFullScreen(on: true)) == .refused(.noWindow))
  }
}
