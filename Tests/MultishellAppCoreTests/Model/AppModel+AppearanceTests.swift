import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelAppearanceTests {
  @Test func theSystemRowStoresNoFontNameAndKeepsTheSize() {
    let harness = Harness()
    harness.model.setTerminalFont(name: "Menlo", size: 15)
    #expect(harness.model.terminalFontPickerID == "Menlo")

    harness.model.setTerminalFontPickerID(FontDetection.systemID)

    #expect(harness.model.workspace.appearance.terminalFontName == nil)
    #expect(harness.model.workspace.appearance.terminalFontSize == 15)
    #expect(harness.model.terminalFontPickerID == FontDetection.systemID)
  }

  @Test func aNewTerminalSizeKeepsTheFamily() {
    let harness = Harness()
    harness.model.setTerminalFont(name: "Menlo", size: 13)

    harness.model.setTerminalFontSize(17)

    #expect(harness.model.workspace.appearance.terminalFontName == "Menlo")
    #expect(harness.model.workspace.appearance.terminalFontSize == 17)
  }

  @Test func aFontSizeOutsideItsSliderIsHeldToTheNearestEnd() {
    let harness = Harness()

    harness.model.setTerminalFontSize(Appearance.terminalFontSizes.upperBound + 10)
    harness.model.setUIFontSize(Appearance.uiFontSizes.lowerBound - 5)

    #expect(
      harness.model.workspace.appearance.terminalFontSize == Appearance.terminalFontSizes.upperBound
    )
    #expect(harness.model.workspace.appearance.uiFontSize == Appearance.uiFontSizes.lowerBound)
  }

  @Test func theDividerRowChangesNothing() {
    let harness = Harness()
    harness.model.setTerminalFontPickerID("Menlo")

    harness.model.setTerminalFontPickerID(DetectionOption.dividerID)

    #expect(harness.model.workspace.appearance.terminalFontName == "Menlo")
  }
}
