import Testing

@testable import MultishellAppCore

/// The terminal font picker's rows.
@Suite
struct FontDetectionTests {
  private let fonts = FontDetection(
    monospaced: ["Menlo", "JetBrains Mono"], others: ["Helvetica", "Avenir"])

  @Test func systemFirstThenMonospacedThenADividerThenTheRestSorted() {
    let ids = fonts.options(selected: nil).map(\.id)
    #expect(
      ids == [
        FontDetection.systemID, "JetBrains Mono", "Menlo", FontDetection.dividerID, "Avenir",
        "Helvetica",
      ])
    #expect(fonts.options(selected: nil)[0].label == "System monospace")
  }

  @Test func aStoredFontTheMachineLacksIsListedMarkedRatherThanDropped() {
    let options = fonts.options(selected: "Fira Code")
    let missing = options.first { $0.id == "Fira Code" }
    #expect(missing?.label == "Fira Code (not installed)" && missing?.isInstalled == false)
    #expect(fonts.options(selected: "Menlo").allSatisfy { $0.isInstalled })
    #expect(fonts.options(selected: FontDetection.systemID).allSatisfy { $0.isInstalled })
  }

  @Test func withNoOtherFamiliesThereIsNoDivider() {
    let only = FontDetection(monospaced: ["Menlo"], others: [])
    #expect(!only.options(selected: nil).map(\.id).contains(FontDetection.dividerID))
  }
}
