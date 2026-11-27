import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

struct FileManagerRunnableFileTests {
  @Test func anExecutableFileRunsAndADirectoryOrPlainFileDoesNot() throws {
    let root = try Scratch.directory("runnable")
    defer { Scratch.remove(root) }
    let plain = root.appendingPathComponent("notes.txt")
    try Data().write(to: plain)

    #expect(FileManager.default.isRunnableFile(atPath: "/bin/sh"))
    #expect(!FileManager.default.isRunnableFile(atPath: root.path))
    #expect(!FileManager.default.isRunnableFile(atPath: plain.path))
    #expect(!FileManager.default.isRunnableFile(atPath: root.appendingPathComponent("gone").path))
  }
}
