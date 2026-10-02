import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func updateSettingsOnlyTouchesThatProject() {
    let store = WorkspaceStore()
    let a = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let b = store.addProject(at: URL(fileURLWithPath: "/repos/b"))

    store.updateSettings(ProjectSettings(branchPrefix: "k/"), forProject: a.id)

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
      confined: SharedProjectSettings(branchPrefix: "team/"), modificationDate: Date(),
      hasBeenRead: true)
    store.updateSharedSettings(read, forProject: project.id)

    let touched = Flag()
    withObservationTracking {
      _ = store.workspace.projects
    } onChange: {
      touched.raise()
    }
    store.updateSharedSettings(read, forProject: project.id)

    #expect(!touched.raised)
    store.updateSharedSettings(SharedSettingsSnapshot.unread, forProject: project.id)
    #expect(touched.raised, "a read that says something else still does")
  }
}
