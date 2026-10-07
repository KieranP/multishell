import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelProjectIconTests {
  @Test func theGlyphAndTintAreWrittenToTheProjectsOwnSettingsAndClearedByNil() {
    let harness = Harness()

    harness.model.setIconGlyph("hammer", for: harness.project)
    harness.model.setIconTint(3, for: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).iconGlyph == "hammer")
    #expect(harness.model.ownSettings(of: harness.project).iconTint == 3)

    harness.model.setIconGlyph(nil, for: harness.project)
    harness.model.setIconTint(nil, for: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).iconGlyph == nil)
    #expect(harness.model.ownSettings(of: harness.project).iconTint == nil)
  }

  @Test func pickingTheFolderStoresNoGlyphRatherThanItsName() {
    let harness = Harness()
    harness.model.setIconGlyph("hammer", for: harness.project)

    harness.model.setIconGlyph(ProjectIcon.folderSymbol, for: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).iconGlyph == nil)
  }

  @Test func settingTheTintLeavesTheGlyphAsItWas() {
    let harness = Harness()
    harness.model.setIconGlyph("hammer", for: harness.project)

    harness.model.setIconTint(5, for: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).iconGlyph == "hammer")
  }
}
