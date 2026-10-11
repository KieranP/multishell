import Foundation
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

  @Test func theSettingsWindowsOpenThroughThePlatformAProjectsNamingIt() async {
    let harness = Harness()

    _ = await harness.messageSource.ask(.showView(.settings, project: nil))
    _ = await harness.messageSource.ask(
      .showView(.projectSettings, project: ControlID.project(harness.project.id))
    )
    _ = await harness.messageSource.ask(.hideView(.settings))

    #expect(harness.platform.shownWindows == [.settings, .projectSettings])
    #expect(harness.platform.closedWindows == [.settings])
    #expect(harness.model.settingsWindowProjectID == harness.project.id)
  }

  @Test func projectSettingsForAnIDNoProjectHasIsRefusedAndOpensNothing() async {
    let harness = Harness()

    #expect(
      await harness.messageSource.ask(.showView(.projectSettings, project: "p-00000000"))
        == .refused(.noProject(id: "p-00000000"))
    )
    #expect(harness.platform.shownWindows.isEmpty)
  }
}
