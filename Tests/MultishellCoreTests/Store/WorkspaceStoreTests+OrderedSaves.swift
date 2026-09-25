import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func aSavePreparedEarlierNeverLandsOverOnePreparedLater() throws {
    let file = Scratch.path("ordered-save").appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = WorkspaceStore(file: WorkspaceFile(fileURL: file))
    store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let first = try #require(store.prepareSave())
    store.addProject(at: URL(fileURLWithPath: "/repos/b"))
    let second = try #require(store.prepareSave())

    try second.run()
    try first.run()

    #expect(try WorkspaceFile(fileURL: file).load().projects.count == 2)
  }
}
