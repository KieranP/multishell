import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSettingsWindowTests {
  @Test func aProjectsMenuOpensTheWindowOnItsFirstPage() {
    let harness = Harness()
    harness.model.showSettings(.terminal, in: .allProjects)

    harness.model.requestSettings(for: harness.project)

    #expect(
      harness.model.settingsLocation
        == SettingsLocation(scope: .project(harness.project.id), section: .general)
    )
  }

  @Test func aProjectsMenuEmptiesASearchThatMayHideItsFirstPage() {
    let harness = Harness()
    harness.model.requestSettings(for: harness.project)
    harness.model.setSettingsSearchText("hook")

    harness.model.requestSettings(for: harness.project)

    #expect(harness.model.settingsSearchText.isEmpty)
  }

  @Test func returningToAllProjectsGoesBackToTheFirstPage() {
    let harness = Harness()
    harness.model.showSettings(.hooksDelete, in: .project(harness.project.id))

    harness.model.returnSettingsToAllProjects()

    #expect(harness.model.settingsLocation == .start)
  }

  @Test func theScopeMenuKeepsThePageWhereTheScopeHasIt() {
    let harness = Harness()
    harness.model.showSettings(.worktrees, in: .allProjects)

    harness.model.setSettingsScope(.project(harness.project.id))

    #expect(harness.model.settingsLocation.section == .worktrees)
  }

  @Test func removingTheProjectShownReturnsTheWindowToAllProjects() {
    let harness = Harness()
    let other = Scratch.path("settings-window")
    defer { Scratch.remove(other) }
    let second = harness.store.addProject(at: other)
    harness.model.requestSettings(for: second)

    harness.model.removeProject(harness.project)
    #expect(harness.model.settingsLocation.scope == .project(second.id), "another project's stays")

    harness.model.removeProject(second)
    #expect(harness.model.settingsLocation == .start)
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

  @Test func returningToAllProjectsEmptiesTheSearch() {
    let harness = Harness()
    harness.model.setSettingsSearchText("zzz")

    harness.model.returnSettingsToAllProjects()

    #expect(harness.model.settingsSearchText.isEmpty)
  }

  @Test func theHeaderSaysWhoseSettingsAreShownAndWhere() {
    let harness = Harness()
    #expect(harness.model.settingsScopeName == "All Projects")
    #expect(harness.model.settingsHeaderCaption == "Applies to every project")

    harness.model.requestSettings(for: harness.project)

    #expect(harness.model.settingsScopeName == harness.project.name)
    #expect(
      harness.model.settingsHeaderCaption == harness.project.path.path.abbreviatingHomeDirectory()
    )
  }

  @Test func theScopeMenuEmptiesTheSearchButAPageOfTheSameScopeKeepsIt() {
    let harness = Harness()
    harness.model.setSettingsSearchText("port")

    harness.model.showSettings(.worktrees, in: .allProjects)
    #expect(harness.model.settingsSearchText == "port")

    harness.model.setSettingsScope(.project(harness.project.id))
    #expect(harness.model.settingsSearchText.isEmpty)
  }
}
