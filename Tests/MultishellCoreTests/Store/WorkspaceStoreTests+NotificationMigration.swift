import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Notifications were one name and are three toggles. Tested through the store, since it
/// is the file on disk that has to survive the first launch and the first save after it.
extension WorkspaceStoreTests {
  @Test func thePickersLastRungComesBackAsThreeTogglesAndIsSavedThatWay() throws {
    let file = try scratchStateFile(
      holding:
        #"{ "projects": [ { "path": "file:///repos/demo/" } ], "notifications": "attentionAndDone" }"#
    )
    defer { Scratch.remove(file.deletingLastPathComponent()) }

    let stateFile = WorkspaceFile(fileURL: file)
    let (store, error) = WorkspaceStore.restored(from: stateFile)
    #expect(error == nil, "\(String(describing: error))")
    #expect(
      store.workspace.notifications
        == NotificationPreference(
          attention: true, failed: true, done: true))

    try store.save()
    let written = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect(
      written["notifications"] as? [String: Bool] == [
        "attention": true, "error": true, "done": true,
      ],
      "written as toggles, not as the name it was read from")

    let (again, reloadError) = WorkspaceStore.restored(from: stateFile)
    #expect(reloadError == nil, "\(String(describing: reloadError))")
    #expect(again.workspace.notifications == store.workspace.notifications)
  }
}
