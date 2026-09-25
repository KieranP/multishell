import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct HelperLinkTests {
  @Test func refreshPointsTheLinkAtTheHelperAndReplacesAStaleOne() throws {
    let root = Scratch.path("helperlink")
    defer { try? FileManager.default.removeItem(at: root) }
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
}
