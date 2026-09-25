import Testing

@testable import MultishellCore

@Suite
struct ProjectSettingsIconSourceTests {
  private func settings(glyph: String? = nil, tint: Int? = nil) -> ProjectSettings {
    ProjectSettings(iconGlyph: glyph, iconTint: tint)
  }

  @Test func aFilesGlyphFillsAProjectWithNone() {
    #expect(settings().takesIconFromSharedFile(SharedProjectSettings(iconGlyph: "star")))
  }

  @Test func aFilesTintFillsAProjectWithNone() {
    #expect(settings().takesIconFromSharedFile(SharedProjectSettings(iconTint: 3)))
  }

  @Test func theProjectsOwnIconWins() {
    let shared = SharedProjectSettings(iconGlyph: "star", iconTint: 3)
    #expect(!settings(glyph: "leaf", tint: 1).takesIconFromSharedFile(shared))
  }

  @Test func aGlyphThatIsNotASymbolNameIsAGapOnEitherSide() {
    #expect(settings(glyph: "🚀").takesIconFromSharedFile(SharedProjectSettings(iconGlyph: "star")))
    #expect(!settings().takesIconFromSharedFile(SharedProjectSettings(iconGlyph: "🚀")))
  }

  @Test func aTintOutsideTheSixteenSlotsIsNoTint() {
    #expect(!settings().takesIconFromSharedFile(SharedProjectSettings(iconTint: 16)))
  }

  @Test func noFileGivesNothing() {
    #expect(!settings().takesIconFromSharedFile(nil))
  }

  @Test func itAgreesWithWhatTheLayeringDraws() {
    let glyphs: [String?] = [nil, "star", "🚀", " "]
    let tints: [Int?] = [nil, 3, 16]
    for ownGlyph in glyphs {
      for ownTint in tints {
        for sharedGlyph in glyphs {
          for sharedTint in tints {
            let own = settings(glyph: ownGlyph, tint: ownTint)
            let shared = SharedProjectSettings(iconGlyph: sharedGlyph, iconTint: sharedTint)
            let drawn = own.layered(over: shared)
            let fromFile =
              drawn.iconGlyph != ProjectIcon.normalizedGlyph(own.iconGlyph)
              || drawn.iconTint != own.iconTint
            #expect(
              own.takesIconFromSharedFile(shared) == fromFile,
              "own \(String(describing: ownGlyph)) \(String(describing: ownTint)), shared \(String(describing: sharedGlyph)) \(String(describing: sharedTint))"
            )
          }
        }
      }
    }
  }
}
