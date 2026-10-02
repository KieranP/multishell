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
}
