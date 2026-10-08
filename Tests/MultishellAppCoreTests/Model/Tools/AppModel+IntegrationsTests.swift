import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelIntegrationsTests {
  @Test func installingTheCommandLineToolAsksThePlatformAndRaisesNothing() {
    let harness = Harness()
    let alertBefore = harness.model.presentedError?.id

    harness.model.installCommandLineTool()

    #expect(harness.platform.installedCommandLineTool)
    #expect(harness.model.presentedError?.id == alertBefore)
  }

  @Test func theToolsLineSaysWhereItIsOrThatItIsNot() {
    let harness = Harness()
    harness.model.isCommandLineToolInstalled = false
    #expect(harness.model.commandLineToolStatusText == "Not installed")

    harness.model.isCommandLineToolInstalled = true

    #expect(harness.model.commandLineToolStatusText == "Installed in /usr/local/bin")
  }
}
