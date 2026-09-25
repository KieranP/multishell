import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct NullPlatformTests {
  @Test func withoutATrashARemovedDirectoryIsDeleted() throws {
    let directory = try Scratch.directory("null")
    try "x".write(to: directory.appendingPathComponent("f"), atomically: true, encoding: .utf8)

    try NullPlatform().moveToTrash(directory)

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

}
