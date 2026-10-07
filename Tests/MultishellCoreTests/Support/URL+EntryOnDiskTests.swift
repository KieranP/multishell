import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct URLEntryOnDiskTests {
  @Test func aDanglingLinkIsAnEntryAndAMissingNameIsNot() throws {
    let root = try Scratch.directory("entry")
    defer { Scratch.remove(root) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: root.appendingPathComponent("nowhere"))

    #expect(link.hasEntryOnDisk)
    #expect(root.hasEntryOnDisk)
    #expect(!root.appendingPathComponent("absent").hasEntryOnDisk)
  }
}
