import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelEffectiveSettingsTests {
  @Test func ownSettingsReadTheStoredProjectAndNotTheCopyPassedIn() {
    let h = Harness()
    let stale = h.project
    var settings = stale.settings
    settings.autoStartAgent = true
    h.model.updateSettings(settings, for: stale)

    #expect(stale.settings.autoStartAgent == nil)
    #expect(h.model.ownSettings(of: stale).autoStartAgent == true)
  }
}
