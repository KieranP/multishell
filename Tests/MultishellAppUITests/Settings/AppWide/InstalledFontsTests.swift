import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct InstalledFontsTests {
  /// The `@State` default reads the cache again each time the settings window
  /// opens.
  @Test func refreshReplacesTheCacheAndNotJustTheView() {
    let detected = InstalledFonts.detection
    #expect(!detected.monospaced.isEmpty, "this Mac has a monospaced font")
    InstalledFonts.detection = FontDetection(monospaced: [], otherFamilies: [])
    #expect(InstalledFonts.refresh() == detected)
    #expect(InstalledFonts.detection == detected)
  }

  @Test func aFamilyIsListedOnlyWhereThePickerOffersIt() {
    let detected = InstalledFonts.refresh()

    for family in detected.monospaced + detected.otherFamilies {
      #expect(InstalledFonts.lists(family), "\(family)")
    }
    #expect(!InstalledFonts.lists("Menloo"))
    #expect(!InstalledFonts.lists(""))
  }
}
