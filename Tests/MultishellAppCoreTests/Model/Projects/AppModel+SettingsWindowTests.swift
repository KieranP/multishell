import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSettingsWindowTests {
  @Test func theSettingsWindowShowsTheProjectAskedForElseTheSelectedOne() {
    let harness = Harness()
    let other = Scratch.path("settings-window")
    defer { Scratch.remove(other) }
    let second = harness.store.addProject(at: other)
    #expect(harness.model.settingsWindowProjectID == nil, "two projects and none selected")

    harness.model.select(harness.main, openingFirstTab: .never)
    #expect(harness.model.settingsWindowProjectID == harness.project.id)

    harness.model.requestSettings(for: second)
    #expect(harness.model.settingsWindowProjectID == second.id)
  }

  @Test func theFallbackProjectFollowsSelectionOrTheOnlyProject() {
    let harness = Harness()
    #expect(
      harness.model.settingsWindowFallbackProject?.id == harness.project.id,
      "one project, nothing selected",
    )
    harness.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(harness.model.settingsWindowFallbackProject == nil, "two projects, nothing selected")
    harness.model.select(harness.feature)
    #expect(harness.model.settingsWindowFallbackProject?.id == harness.project.id)
  }
}
