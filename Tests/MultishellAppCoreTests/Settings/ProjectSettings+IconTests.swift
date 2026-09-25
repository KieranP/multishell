import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ProjectSettingsIconTests {
  @Test func aGlyphFromThePaletteDrawsAsItsSymbol() {
    let settings = ProjectSettings(iconGlyph: "hammer")
    #expect(settings.iconKind == .symbol("hammer"))
    #expect(settings.iconKind.symbolName == "hammer")
  }

  @Test func noGlyphOrOneOffThePaletteDrawsTheFolder() {
    #expect(ProjectSettings().iconKind == .folder)
    #expect(ProjectSettings(iconGlyph: "not.a.symbol").iconKind == .folder)
    #expect(ProjectSettings().iconKind.symbolName == ProjectIcon.folderSymbol)
  }
}
