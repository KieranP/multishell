import Testing

@testable import MultishellCore

@Suite
struct ProjectIconTests {
  @Test func aGlyphIsASymbolNameOrNothing() {
    #expect(ProjectIcon.kind(of: nil) == .folder)
    #expect(ProjectIcon.kind(of: "") == .folder)
    #expect(ProjectIcon.kind(of: "  ") == .folder)
    #expect(ProjectIcon.kind(of: "hammer") == .symbol("hammer"))
    #expect(ProjectIcon.kind(of: " hammer ") == .symbol("hammer"))
    #expect(ProjectIcon.kind(of: "not.a.symbol") == .folder, "only the curated list is drawn")
    #expect(
      ProjectIcon.kind(of: "🚀") == .folder,
      "an emoji a build that offered them stored draws the folder, not a blank")
  }

  @Test func tintsOutsideTheThemeAreNone() {
    #expect(ProjectIcon.usableTint(nil) == nil)
    #expect(ProjectIcon.usableTint(-1) == nil)
    #expect(ProjectIcon.usableTint(16) == nil)
    #expect(ProjectIcon.usableTint(0) == 0)
    #expect(ProjectIcon.usableTint(15) == 15)
    #expect(ProjectSettings(iconTint: 40).iconTint == nil)
  }

  @Test func theCuratedSymbolsAreDistinctAndPlain() {
    #expect(Set(ProjectIcon.symbols).count == ProjectIcon.symbols.count)
    #expect(ProjectIcon.symbols.allSatisfy { $0.unicodeScalars.allSatisfy(\.isASCII) })
  }

  @Test func everySymbolIsInOneNamedGroup() {
    let groups = ProjectIcon.symbolGroups
    #expect(!groups.isEmpty)
    #expect(groups.allSatisfy { !$0.name.isEmpty && !$0.symbols.isEmpty })
    #expect(Set(groups.map(\.name)).count == groups.count)
    #expect(
      groups.first?.symbols.first == ProjectIcon.folderSymbol,
      "the folder is the first cell, and picking it is what goes back to no glyph")
  }

  @Test func onlyASymbolNameCountsAsAGlyph() {
    #expect(ProjectIcon.normalizedGlyph("hammer") == "hammer")
    #expect(ProjectIcon.normalizedGlyph("  hammer  ") == "hammer")
    #expect(
      ProjectIcon.normalizedGlyph("sparkle.magnifyingglass") == "sparkle.magnifyingglass",
      "a name this build does not carry may still be one a teammate's build draws")
    #expect(ProjectIcon.normalizedGlyph("🚀") == nil, "no build draws an emoji any more")
    #expect(ProjectIcon.normalizedGlyph("") == nil)
    #expect(ProjectIcon.normalizedGlyph(nil) == nil)
  }
}
