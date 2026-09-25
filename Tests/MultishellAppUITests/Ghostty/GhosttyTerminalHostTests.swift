import Foundation
import GhosttyTerminal
import Testing

@testable import MultishellAppUI

/// The generated config directory is shared by every copy of the build, so a
/// launch that quits without opening a surface must leave it alone.
@Suite(.serialized)
@MainActor
struct GhosttyTerminalHostTests {
  private func plantedFile() throws -> URL {
    let directory = TerminalController.managedConfigDirectory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("ghostty-config-\(UUID().uuidString).conf")
    try "font-size = 13".write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  @Test func buildingTheHostDoesNotTouchTheDirectory() throws {
    let file = try plantedFile()
    defer { try? FileManager.default.removeItem(at: file) }

    _ = GhosttyTerminalHost()

    #expect(FileManager.default.fileExists(atPath: file.path))
  }

  @Test func aCopyThatNeverClaimedTheFilesSweepsNothingOnQuit() throws {
    let file = try plantedFile()
    defer { try? FileManager.default.removeItem(at: file) }

    let host = GhosttyTerminalHost()
    host.shutDown()

    #expect(FileManager.default.fileExists(atPath: file.path))
  }

  @Test func theCopyHoldingTheSocketSweepsWhatAnEarlierRunLeft() throws {
    let file = try plantedFile()
    defer { try? FileManager.default.removeItem(at: file) }

    GhosttyTerminalHost().claimSharedFiles()

    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func theCopyHoldingTheSocketSweepsAgainOnQuit() throws {
    let host = GhosttyTerminalHost()
    host.claimSharedFiles()
    let file = try plantedFile()
    defer { try? FileManager.default.removeItem(at: file) }

    host.shutDown()

    #expect(!FileManager.default.fileExists(atPath: file.path))
  }
}
