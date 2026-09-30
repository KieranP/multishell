import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelProjectIconTests {
  @Test func theGlyphAndTintAreWrittenToTheProjectsOwnSettingsAndClearedByNil() {
    let h = Harness()

    h.model.setIconGlyph("hammer", for: h.project)
    h.model.setIconTint(3, for: h.project)

    #expect(h.model.ownSettings(of: h.project).iconGlyph == "hammer")
    #expect(h.model.ownSettings(of: h.project).iconTint == 3)

    h.model.setIconGlyph(nil, for: h.project)
    h.model.setIconTint(nil, for: h.project)

    #expect(h.model.ownSettings(of: h.project).iconGlyph == nil)
    #expect(h.model.ownSettings(of: h.project).iconTint == nil)
  }

  @Test func settingTheTintLeavesTheGlyphAsItWas() {
    let h = Harness()
    h.model.setIconGlyph("hammer", for: h.project)

    h.model.setIconTint(5, for: h.project)

    #expect(h.model.ownSettings(of: h.project).iconGlyph == "hammer")
  }
}
