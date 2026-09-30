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
}
