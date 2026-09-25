import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelShellTests {
  @Test func theCustomPathFieldShowsOnlyForTheCustomShell() {
    let h = Harness()
    #expect(!h.model.usesCustomShell)

    h.model.setPreferredShell(ShellCatalogue.customID)
    #expect(h.model.usesCustomShell)

    h.model.setPreferredShell(ShellCatalogue.loginShellID)
    #expect(!h.model.usesCustomShell)
  }
}
