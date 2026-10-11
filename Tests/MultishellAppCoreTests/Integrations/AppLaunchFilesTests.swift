import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct AppLaunchFilesTests {
  @Test func aLinkThatCannotBeMadeStillLeavesTheOtherLinkAndTheShellIntegrationWritten() throws {
    let root = Scratch.path("launchfiles")
    defer { Scratch.remove(root) }
    let helper = root.appendingPathComponent("A.app/Contents/Helpers/multishell")
    try FileManager.default.createDirectory(
      at: helper.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try Data().write(to: helper)
    let blocked = root.appendingPathComponent("cli.debug")
    try Data().write(to: blocked)
    let shared = root.appendingPathComponent("bin/multishell")
    var wroteIntegration = false

    #expect(throws: (any Error).self) {
      try AppLaunchFiles.refresh(
        helper: helper,
        links: [blocked.appendingPathComponent("multishell"), shared],
        writeShellIntegration: { wroteIntegration = true },
      )
    }

    #expect(wroteIntegration)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: shared.path) == helper.path)
  }
}
