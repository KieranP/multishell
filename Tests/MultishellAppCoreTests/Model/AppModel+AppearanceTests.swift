import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelAppearanceTests {
  @Test func theSystemRowStoresNoFontNameAndKeepsTheSize() {
    let h = Harness()
    h.model.setFont(name: "Menlo", size: 15)
    #expect(h.model.fontPickerID == "Menlo")

    h.model.setFontName(FontDetection.systemID)

    #expect(h.model.workspace.appearance.fontName == nil)
    #expect(h.model.workspace.appearance.fontSize == 15)
    #expect(h.model.fontPickerID == FontDetection.systemID)
  }

  @Test func aNewTerminalSizeKeepsTheFamily() {
    let h = Harness()
    h.model.setFont(name: "Menlo", size: 13)

    h.model.setFontSize(17)

    #expect(h.model.workspace.appearance.fontName == "Menlo")
    #expect(h.model.workspace.appearance.fontSize == 17)
  }

  @Test func theDividerRowChangesNothing() {
    let h = Harness()
    h.model.setFontName("Menlo")

    h.model.setFontName(DetectionOption.dividerID)

    #expect(h.model.workspace.appearance.fontName == "Menlo")
  }
}
