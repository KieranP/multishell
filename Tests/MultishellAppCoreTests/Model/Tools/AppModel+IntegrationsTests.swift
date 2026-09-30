import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelIntegrationsTests {
  @Test func installingTheCommandLineToolAsksThePlatformAndRaisesNothing() {
    let h = Harness()
    let alertBefore = h.model.presentedError?.id

    h.model.installCommandLineTool()

    #expect(h.platform.installedCommandLineTool)
    #expect(h.model.presentedError?.id == alertBefore)
  }
}
