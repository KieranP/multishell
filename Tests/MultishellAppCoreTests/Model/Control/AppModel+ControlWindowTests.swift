import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlWindowTests {
  @Test func theWindowIsSizedAndAClosedOneIsRefused() async {
    let harness = Harness()

    #expect(await harness.messageSource.ask(.resizeWindow(width: 900, height: 600)) == .done)
    #expect(harness.platform.workspaceWindowSize?.width == 900)
    #expect(harness.platform.workspaceWindowSize?.height == 600)

    harness.platform.workspaceWindowSize = nil
    #expect(
      await harness.messageSource.ask(.resizeWindow(width: 900, height: 600)) == .refused(.noWindow)
    )
  }

  @Test func aWindowInFullScreenIsNotSizedAsItWouldShrinkInsideTheScreen() async {
    let harness = Harness()
    harness.platform.workspaceWindowSize = (1_200, 800)
    harness.platform.isWorkspaceWindowFullScreen = true

    #expect(
      await harness.messageSource.ask(.resizeWindow(width: 900, height: 600))
        == .refused(.windowInFullScreen)
    )
    #expect(harness.platform.workspaceWindowSize?.width == 1_200)
  }

  @Test func theWindowGoesIntoFullScreenAndOutAndAClosedOneIsRefused() async {
    let harness = Harness()

    #expect(await harness.messageSource.ask(.setFullScreen(on: true)) == .done)
    #expect(harness.platform.isWorkspaceWindowFullScreen)
    #expect(await harness.messageSource.ask(.setFullScreen(on: false)) == .done)
    #expect(!harness.platform.isWorkspaceWindowFullScreen)

    harness.platform.workspaceWindowSize = nil
    #expect(await harness.messageSource.ask(.setFullScreen(on: true)) == .refused(.noWindow))
  }
}
