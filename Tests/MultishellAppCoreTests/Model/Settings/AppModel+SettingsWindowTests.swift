import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSettingsWindowTests {
  @Test func aProjectsMenuOpensTheWindowOnItsFirstPage() {
    let harness = Harness()
    harness.model.showSettings(.terminal, in: .allProjects)

    harness.model.showSettings(of: harness.project)

    #expect(
      harness.model.settingsLocation
        == SettingsLocation(scope: .project(harness.project.id), section: .general)
    )
  }

  @Test func theScopeMenuTellsTwoProjectsOfOneNameApartByPath() {
    let harness = Harness()
    let other = harness.store.addProject(
      at: URL(fileURLWithPath: "/repos/elsewhere/\(harness.project.name)")
    )

    let labels = harness.model.settingsScopeLabels

    #expect(labels[harness.project.id] != labels[other.id])
    #expect(
      labels[other.id] == "\(harness.project.name)  (/repos/elsewhere/\(harness.project.name))"
    )
  }

  @Test func aProjectsMenuEmptiesASearchThatMayHideItsFirstPage() {
    let harness = Harness()
    harness.model.showSettings(of: harness.project)
    harness.model.setSettingsSearchText("hook")

    harness.model.showSettings(of: harness.project)

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

    harness.model.showSettings(of: harness.project)

    #expect(harness.model.settingsScopeName == harness.project.name)
    #expect(
      harness.model.settingsHeaderCaption == harness.project.path.path.abbreviatingHomeDirectory()
    )
  }

  @Test func aScopeIsNamedForItselfWhicheverScopeTheWindowShows() {
    let harness = Harness()

    let projectScope = SettingsScope.project(harness.project.id)
    #expect(harness.model.settingsScopeName(of: projectScope) == harness.project.name)

    harness.model.showSettings(of: harness.project)

    #expect(harness.model.settingsScopeName(of: .allProjects) == "All Projects")
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
