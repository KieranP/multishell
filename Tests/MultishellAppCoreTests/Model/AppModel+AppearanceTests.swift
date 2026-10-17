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

  @Test func theFileFontAndSizeAreSetApartFromTheTerminalsAndClamped() {
    let harness = Harness()
    harness.model.setTerminalFont(name: "Menlo", size: 15)

    harness.model.setFileFontPickerID("Courier")
    harness.model.setFileFontSize(Appearance.fileFontSizes.upperBound + 10)
    harness.model.setFileFontPickerID(DetectionOption.dividerID)

    #expect(harness.model.workspace.appearance.fileFontName == "Courier")
    #expect(harness.model.fileFontPickerID == "Courier")
    #expect(harness.model.workspace.appearance.fileFontSize == Appearance.fileFontSizes.upperBound)
    #expect(harness.model.workspace.appearance.terminalFontName == "Menlo")
    #expect(harness.model.workspace.appearance.terminalFontSize == 15)
    harness.model.setFileFontPickerID(FontDetection.systemID)
    #expect(harness.model.workspace.appearance.fileFontName == nil)
  }

  @Test func theUIFontFamilyIsSetApartFromItsSize() {
    let harness = Harness()
    harness.model.setUIFontSize(15)

    harness.model.setUIFontPickerID("Avenir Next")
    harness.model.setUIFontPickerID(DetectionOption.dividerID)

    #expect(harness.model.workspace.appearance.uiFontName == "Avenir Next")
    #expect(harness.model.uiFontPickerID == "Avenir Next")
    #expect(harness.model.workspace.appearance.uiFontSize == 15)
    harness.model.setUIFontPickerID(FontDetection.systemID)
    #expect(harness.model.workspace.appearance.uiFontName == nil)
  }
}
