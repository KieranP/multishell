import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ExecutableLookupTests {
  @Test func aToolOnTheProcessPathIsFound() {
    #expect(ExecutableLookup.find("sh") != nil)
    #expect(ExecutableLookup.find("git") != nil)
  }

  @Test func aToolNoPathDirectoryHoldsIsNotFound() {
    #expect(ExecutableLookup.find("definitely-not-a-real-binary-\(UUID().uuidString)") == nil)
  }

  @Test func executableLookupWalksTheGivenPathNotTheProcessOne() throws {
    let directory = try Scratch.directory("path")
    defer { Scratch.remove(directory) }
    let fake = try Scratch.script("exit 0", at: directory.appendingPathComponent("claude"))
    try "not executable".write(
      to: directory.appendingPathComponent("codex"),
      atomically: true,
      encoding: .utf8,
    )

    let path = "/nowhere:\(directory.path):/bin"
    #expect(ExecutableLookup.find("claude", searchPath: path)?.path == fake.path)
    #expect(ExecutableLookup.find("codex", searchPath: path) == nil, "present but not executable")
    #expect(ExecutableLookup.find("sh", searchPath: path) != nil)
    #expect(ExecutableLookup.find("claude", searchPath: "/usr/bin") == nil)
  }

  @Test func aDirectoryOfTheToolsNameIsPassedOverForTheToolLaterOnThePath() throws {
    let root = try Scratch.directory("path")
    defer { Scratch.remove(root) }
    let early = root.appendingPathComponent("early")
    let late = root.appendingPathComponent("late")
    try FileManager.default.createDirectory(
      at: early.appendingPathComponent("git"),
      withIntermediateDirectories: true,
    )
    try FileManager.default.createDirectory(at: late, withIntermediateDirectories: true)
    let tool = try Scratch.script("exit 0", at: late.appendingPathComponent("git"))

    let found = ExecutableLookup.find("git", searchPath: "\(early.path):\(late.path)")

    #expect(found?.path == tool.path)
  }
}
