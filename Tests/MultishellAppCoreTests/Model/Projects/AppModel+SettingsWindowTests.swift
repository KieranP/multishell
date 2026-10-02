import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSettingsWindowTests {
  @Test func theSettingsWindowShowsTheProjectAskedForElseTheSelectedOne() {
    let h = Harness()
    let other = Scratch.path("settings-window")
    defer { Scratch.remove(other) }
    let second = h.store.addProject(at: other)
    #expect(h.model.settingsWindowProjectID == nil, "two projects and none selected")

    h.model.select(h.main, openingFirstTab: .never)
    #expect(h.model.settingsWindowProjectID == h.project.id)

    h.model.requestedSettingsProjectID = second.id
    #expect(h.model.settingsWindowProjectID == second.id)
  }

  @Test func theFallbackProjectFollowsSelectionOrTheOnlyProject() {
    let h = Harness()
    #expect(
      h.model.settingsWindowFallbackProject?.id == h.project.id, "one project, nothing selected")
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(h.model.settingsWindowFallbackProject == nil, "two projects, nothing selected")
    h.model.select(h.feature)
    #expect(h.model.settingsWindowFallbackProject?.id == h.project.id)
  }
}
