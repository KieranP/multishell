import MultishellCore
import Testing

@testable import MultishellAppCore

/// Everything the model wants from the desktop goes through the port, so a
/// second frontend implements one protocol and the model is untouched.
@Suite @MainActor
struct AppModelDesktopTests {
  @Test func revealingAndCopyingGoThroughThePlatform() {
    let harness = Harness()
    harness.model.revealInFileBrowser(harness.main.path)
    harness.model.copyToClipboard("feature")
    #expect(harness.platform.revealed == [harness.main.path])
    #expect(harness.platform.clipboard == ["feature"])
  }
}
