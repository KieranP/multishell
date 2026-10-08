import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func aSavePreparedEarlierNeverLandsOverOnePreparedLater() throws {
    let file = Scratch.statePath("ordered-save")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let store = WorkspaceStore(file: StateFile(fileURL: file))
    store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let first = try #require(store.prepareSave())
    store.addProject(at: URL(fileURLWithPath: "/repos/b"))
    let second = try #require(store.prepareSave())

    try second.write()
    try first.write()

    #expect(try StateFile(fileURL: file).load().projects.count == 2)
  }
}
