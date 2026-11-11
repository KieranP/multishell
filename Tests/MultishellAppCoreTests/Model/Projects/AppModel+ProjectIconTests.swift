import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

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

  @Test func pickingTheFolderOverTheRepositorysGlyphDrawsTheFolder() throws {
    let harness = Harness()
    let shared = SharedProjectSettings(iconGlyph: "hammer")
    harness.store.setSharedSettingsSnapshot(
      SharedSettingsSnapshot(asWritten: shared, confined: shared, hasBeenRead: true),
      forProject: harness.project.id,
    )
    let withFile = try #require(harness.model.workspace.project(harness.project.id))

    harness.model.setIconGlyph(ProjectIcon.folderSymbol, for: withFile)

    let project = try #require(harness.model.workspace.project(harness.project.id))
    #expect(harness.model.effectiveSettings(for: project).iconKind == .folder)
    #expect(!harness.model.ownSettings(of: project).takesIconFromSharedFile(shared))
  }

  @Test func pickingNoTintOverTheRepositorysTintDrawsNoneAndIsKept() throws {
    let harness = Harness()
    let shared = SharedProjectSettings(iconTint: 3)
    harness.store.setSharedSettingsSnapshot(
      SharedSettingsSnapshot(asWritten: shared, confined: shared, hasBeenRead: true),
      forProject: harness.project.id,
    )
    let withFile = try #require(harness.model.workspace.project(harness.project.id))

    harness.model.setIconTint(nil, for: withFile)

    let project = try #require(harness.model.workspace.project(harness.project.id))
    #expect(harness.model.effectiveSettings(for: project).iconTint == nil)
    #expect(!harness.model.ownSettings(of: project).takesIconFromSharedFile(shared))
    let saved = try JSONEncoder().encode(harness.model.ownSettings(of: project))
    let reloaded = try JSONDecoder().decode(ProjectSettings.self, from: saved)
    #expect(reloaded.layered(over: shared).iconTint == nil, "kept across a relaunch")
  }

  @Test func settingTheTintLeavesTheGlyphAsItWas() {
    let harness = Harness()
    harness.model.setIconGlyph("hammer", for: harness.project)

    harness.model.setIconTint(5, for: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).iconGlyph == "hammer")
  }
}
