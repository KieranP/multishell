import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ExecutableLookupTests {
  @Test func findsToolsOnPath() {
    #expect(ExecutableLookup.find("sh") != nil)
    #expect(ExecutableLookup.find("git") != nil)
  }

  @Test func returnsNilForMissingTools() {
    #expect(ExecutableLookup.find("definitely-not-a-real-binary-\(UUID().uuidString)") == nil)
  }

  @Test func executableLookupWalksTheGivenPathNotTheProcessOne() throws {
    let directory = try Scratch.directory("path")
    defer { try? FileManager.default.removeItem(at: directory) }
    let fake = directory.appendingPathComponent("claude")
    try "#!/bin/sh\nexit 0\n".write(to: fake, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
    try "not executable".write(
      to: directory.appendingPathComponent("codex"), atomically: true, encoding: .utf8)

    let path = "/nowhere:\(directory.path):/bin"
    #expect(ExecutableLookup.find("claude", searchPath: path)?.path == fake.path)
    #expect(ExecutableLookup.find("codex", searchPath: path) == nil, "present but not executable")
    #expect(ExecutableLookup.find("sh", searchPath: path) != nil)
    #expect(ExecutableLookup.find("claude", searchPath: "/usr/bin") == nil)
  }
}
