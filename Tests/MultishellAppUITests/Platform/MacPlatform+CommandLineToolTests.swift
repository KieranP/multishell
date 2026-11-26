import Foundation
import TestScratch
import Testing

@testable import MultishellAppUI

@Suite(.serialized)
@MainActor
struct MacPlatformCommandLineToolTests {
  @Test func installingOverALinkChainEndingInAFolderReplacesTheLinkAndLeavesTheFolderAlone()
    throws
  {
    let root = try Scratch.directory("install-tool")
    defer { Scratch.remove(root) }
    let folder = root.appending(path: "victim")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let shared = root.appending(path: "shared")
    try FileManager.default.createSymbolicLink(at: shared, withDestinationURL: folder)
    let link = root.appending(path: "multishell")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: shared)
    let target = root.appending(path: "helper").path
    let command = try #require(
      try AppleScriptRunner.call(
        MacPlatform.installToolScript,
        handler: "installCommand",
        arguments: [target, root.path, link.path],
      )
    )

    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", command]
    try shell.run()
    shell.waitUntilExit()

    #expect(shell.terminationStatus == 0)
    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == target)
  }
}
