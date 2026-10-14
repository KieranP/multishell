import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct HelperLinkTests {
  @Test func refreshPointsTheLinkAtTheHelperAndReplacesAStaleOne() throws {
    let root = Scratch.path("helperlink")
    defer { Scratch.remove(root) }
    let link = root.appendingPathComponent("bin/multishell")
    let old = root.appendingPathComponent("old/multishell")
    let new = root.appendingPathComponent("new/multishell")

    try HelperLink.refresh(to: old, link: link)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == old.path)
    try HelperLink.refresh(to: new, link: link)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == new.path)
    try HelperLink.refresh(to: new, link: link)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == new.path)

    let untouched = root.appendingPathComponent("none/multishell")
    try HelperLink.refresh(to: nil, link: untouched)
    #expect(!FileManager.default.fileExists(atPath: untouched.path), "no helper, no link")
  }

  @Test func theToolIsOfferedOverNothingADanglingLinkOrTheSharedLinkOnly() throws {
    let root = Scratch.path("helperlink")
    defer { Scratch.remove(root) }
    let tool = root.appendingPathComponent("usr-local-bin/multishell")
    let shared = root.appendingPathComponent("bin/multishell")
    let otherBuilds = root.appendingPathComponent("cli/multishell")
    let gone = root.appendingPathComponent("cli.debug-removed/multishell")
    let helper = root.appendingPathComponent("A.app/Contents/Helpers/multishell")
    for directory in [tool, helper].map({ $0.deletingLastPathComponent() }) {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    try Data().write(to: helper)
    try HelperLink.refresh(to: helper, link: shared)
    try HelperLink.refresh(to: helper, link: otherBuilds)
    let installed = { HelperLink.isCommandLineToolInstalled(link: tool, sharedLink: shared) }

    #expect(!installed(), "nothing there")
    try FileManager.default.createSymbolicLink(at: tool, withDestinationURL: shared)
    #expect(!installed(), "the shared link is whichever build launched last")
    try FileManager.default.removeItem(at: tool)
    try FileManager.default.createSymbolicLink(at: tool, withDestinationURL: gone)
    #expect(!installed(), "a link to a build since deleted")
    try FileManager.default.removeItem(at: tool)
    try FileManager.default.createSymbolicLink(at: tool, withDestinationURL: otherBuilds)
    #expect(installed(), "another build's own link")
    try FileManager.default.removeItem(at: tool)
    try Data("#!/bin/sh\n".utf8).write(to: tool)
    #expect(installed(), "a file of the user's own")
  }
}
