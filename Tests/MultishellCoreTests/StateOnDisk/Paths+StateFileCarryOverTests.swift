import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct PathsStateFileCarryOverTests {
  @Test func aStateFileSavedUnderTheCutNameFromBeforeTheHashIsCarriedOver() throws {
    let root = try Scratch.directory("carry-over")
    defer { Scratch.remove(root) }
    let name = "feature-sidebar-filter"
    let before = root.appendingPathComponent("state.debug-feature-sideba.json")
    let now = root.appendingPathComponent("state\(Paths.debugVariant(named: name)).json")
    try Data("{\"saved\":1}".utf8).write(to: before)

    Paths.carryOverStateFileFromBeforeTheHash(named: name, in: root)

    #expect(try Data(contentsOf: now) == Data("{\"saved\":1}".utf8))
    #expect(!FileManager.default.fileExists(atPath: before.path))
  }

  @Test func aStateFileAlreadyUnderTheHashedNameIsNotReplaced() throws {
    let root = try Scratch.directory("carry-over")
    defer { Scratch.remove(root) }
    let name = "feature-sidebar-filter"
    let before = root.appendingPathComponent("state.debug-feature-sideba.json")
    let now = root.appendingPathComponent("state\(Paths.debugVariant(named: name)).json")
    try Data("old".utf8).write(to: before)
    try Data("new".utf8).write(to: now)

    Paths.carryOverStateFileFromBeforeTheHash(named: name, in: root)

    #expect(try Data(contentsOf: now) == Data("new".utf8))
    #expect(FileManager.default.fileExists(atPath: before.path))
  }
}
