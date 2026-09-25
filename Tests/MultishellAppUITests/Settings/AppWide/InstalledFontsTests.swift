import MultishellAppCore
import MultishellCore
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct InstalledFontsTests {
  /// Refresh has to replace the cache, not just the view: the `@State`
  /// default reads it again each time the settings window opens.
  @Test func refreshReplacesTheCacheAndNotJustTheView() {
    #expect(!InstalledFonts.all.monospaced.isEmpty, "this Mac has a monospaced font")
    let reloaded = InstalledFonts.reload()
    #expect(reloaded == InstalledFonts.all)
  }
}
