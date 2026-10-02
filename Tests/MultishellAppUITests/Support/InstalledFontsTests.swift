import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct InstalledFontsTests {
  /// Refresh has to replace the cache, not just the view: the `@State`
  /// default reads it again each time the settings window opens.
  @Test func refreshReplacesTheCacheAndNotJustTheView() {
    let detected = InstalledFonts.all
    #expect(!detected.monospaced.isEmpty, "this Mac has a monospaced font")
    InstalledFonts.all = FontDetection(monospaced: [], otherFamilies: [])
    #expect(InstalledFonts.reload() == detected)
    #expect(InstalledFonts.all == detected)
  }
}
