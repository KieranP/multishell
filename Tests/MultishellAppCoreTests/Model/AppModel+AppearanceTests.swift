import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelAppearanceTests {
  @Test func theSystemRowStoresNoFontNameAndKeepsTheSize() {
    let h = Harness()
    h.model.setTerminalFont(name: "Menlo", size: 15)
    #expect(h.model.terminalFontPickerID == "Menlo")

    h.model.setTerminalFontName(FontDetection.systemID)

    #expect(h.model.workspace.appearance.terminalFontName == nil)
    #expect(h.model.workspace.appearance.terminalFontSize == 15)
    #expect(h.model.terminalFontPickerID == FontDetection.systemID)
  }

  @Test func aNewTerminalSizeKeepsTheFamily() {
    let h = Harness()
    h.model.setTerminalFont(name: "Menlo", size: 13)

    h.model.setTerminalFontSize(17)

    #expect(h.model.workspace.appearance.terminalFontName == "Menlo")
    #expect(h.model.workspace.appearance.terminalFontSize == 17)
  }

  @Test func theDividerRowChangesNothing() {
    let h = Harness()
    h.model.setTerminalFontName("Menlo")

    h.model.setTerminalFontName(DetectionOption.dividerID)

    #expect(h.model.workspace.appearance.terminalFontName == "Menlo")
  }
}
