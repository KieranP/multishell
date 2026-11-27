import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct URLContainmentTests {
  @Test func aPathIsUnderABaseByWholeComponentOnly() {
    let base = URL(fileURLWithPath: "/a/b", isDirectory: true)
    #expect(URL(fileURLWithPath: "/a/b/c/d").pathComponents(under: base) == ["c", "d"])
    #expect(URL(fileURLWithPath: "/a/b").pathComponents(under: base) == [])
    #expect(URL(fileURLWithPath: "/a/bc").pathComponents(under: base) == nil)
    #expect(URL(fileURLWithPath: "/x").pathComponents(under: URL(fileURLWithPath: "/")) == ["x"])
  }

  @Test func aLinkLeadingOutOfARootIsNotStrictlyUnderIt() throws {
    let root = try Scratch.directory("containment")
    defer { Scratch.remove(root) }
    let inside = root.appendingPathComponent("inside")
    try FileManager.default.createDirectory(
      at: inside.appendingPathComponent("a"),
      withIntermediateDirectories: true,
    )
    try FileManager.default.createSymbolicLink(
      at: inside.appendingPathComponent("out"),
      withDestinationURL: root,
    )
    try FileManager.default.createSymbolicLink(
      at: inside.appendingPathComponent("here"),
      withDestinationURL: inside.appendingPathComponent("a"),
    )

    #expect(
      inside.appendingPathComponent("here/b").resolvedComponents(strictlyUnder: inside)
        == ["a", "b"]
    )
    #expect(inside.appendingPathComponent("out").resolvedComponents(strictlyUnder: inside) == nil)
    #expect(inside.resolvedComponents(strictlyUnder: inside) == nil)
  }
}
