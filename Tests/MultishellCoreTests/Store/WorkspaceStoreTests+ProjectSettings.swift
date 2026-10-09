import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func settingOneProjectsSettingsLeavesTheOtherAlone() {
    let store = WorkspaceStore()
    let a = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let b = store.addProject(at: URL(fileURLWithPath: "/repos/b"))

    store.setSettings(ProjectSettings(branchPrefix: "k/"), forProject: a.id)

    #expect(store.workspace.project(a.id)?.settings.branchPrefix == "k/")
    #expect(store.workspace.project(b.id)?.settings.branchPrefix == nil)
  }

  /// Every activation re-reads each project's file, and a mutation is a
  /// whole-workspace save. Reading the same bytes is not a change.
  @Test func rereadingTheSameSharedSettingsTouchesNothing() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let read = SharedSettingsSnapshot(
      asWritten: SharedProjectSettings(branchPrefix: "team/"),
      confined: SharedProjectSettings(branchPrefix: "team/"),
      modificationDate: Date(),
      hasBeenRead: true,
    )
    store.setSharedSettingsSnapshot(read, forProject: project.id)

    let counter = ChangeCounter(store)
    store.setSharedSettingsSnapshot(read, forProject: project.id)

    #expect(counter.changes == 0)
    store.setSharedSettingsSnapshot(SharedSettingsSnapshot.unread, forProject: project.id)
    #expect(counter.changes == 1, "a read that says something else still does")
  }
}
