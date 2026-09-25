import MultishellCore
import Testing

@testable import MultishellAppCore

/// Everything the model wants from the desktop goes through the port, so a
/// second frontend implements one protocol and the model is untouched.
@Suite @MainActor
struct AppModelDesktopTests {
  @Test func revealingAndCopyingGoThroughThePlatform() {
    let h = Harness()
    h.model.revealInFileBrowser(h.main.path)
    h.model.copyToClipboard("feature")
    #expect(h.platform.revealed == [h.main.path])
    #expect(h.platform.clipboard == ["feature"])
  }
}
