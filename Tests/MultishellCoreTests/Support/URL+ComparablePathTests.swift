import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct URLComparablePathTests {
  @Test func aLinkAndADotDotSpellingResolveToTheDirectoryTheyName() throws {
    let root = try Scratch.directory("resolved-path")
    defer { Scratch.remove(root) }
    let target = root.appendingPathComponent("target", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    #expect(link.comparablePath == target.comparablePath)
    #expect(target.appendingPathComponent("../target").comparablePath == target.comparablePath)
    #expect(link.comparablePath != link.path)
  }
}
