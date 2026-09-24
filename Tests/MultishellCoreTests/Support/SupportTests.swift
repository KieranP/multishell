import Foundation
import Testing

@testable import MultishellCore

@Suite
struct SupportTests {
  @Test func aPathIsUnderABaseByWholeComponentOnly() {
    let base = URL(fileURLWithPath: "/a/b", isDirectory: true)
    #expect(URL(fileURLWithPath: "/a/b/c/d").pathComponents(under: base) == ["c", "d"])
    #expect(URL(fileURLWithPath: "/a/b").pathComponents(under: base) == [])
    #expect(URL(fileURLWithPath: "/a/bc").pathComponents(under: base) == nil)
    #expect(URL(fileURLWithPath: "/x").pathComponents(under: URL(fileURLWithPath: "/")) == ["x"])
  }

  @Test func aPathSplitsAtItsDeepestExistingPartADanglingLinkIncluded() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: root.appendingPathComponent("nowhere"))

    let missing = root.appendingPathComponent("a/b").splitAtDeepestExisting()
    #expect(missing.existing.path == root.standardizedFileURL.path)
    #expect(missing.unmade == ["a", "b"])

    let dangling = link.appendingPathComponent("c").splitAtDeepestExisting()
    #expect(dangling.existing.path == link.standardizedFileURL.path)
    #expect(dangling.unmade == ["c"])

    #expect(root.splitAtDeepestExisting().unmade.isEmpty)
  }

  @Test func aPathResolvesAsFarAsItExistsADanglingLinkRefusedUnlessKept() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let real = try #require(realpath(root.path, nil))
    defer { free(real) }
    let resolvedRoot = String(cString: real)
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("target"), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("link"),
      withDestinationURL: root.appendingPathComponent("target"))
    let dangling = root.appendingPathComponent("dangling")
    try FileManager.default.createSymbolicLink(
      at: dangling, withDestinationURL: root.appendingPathComponent("nowhere"))

    #expect(
      root.appendingPathComponent("link/a/b").resolvedAsFarAsItExists()?.path
        == resolvedRoot + "/target/a/b")
    #expect(dangling.appendingPathComponent("c").resolvedAsFarAsItExists() == nil)
    #expect(
      dangling.appendingPathComponent("c").resolvedAsFarAsItExists(keepingDanglingLinks: true)?
        .path == resolvedRoot + "/dangling/c")
  }

  @Test func aLineListDropsBlanksAndCommentsAndTrimsTheRest() {
    #expect(LineList.entries(in: " a \n\n# no\nb\r\n") == ["a", "b"])
    #expect(LineList.entries(in: "   \n\n").isEmpty)
  }

  @Test func theHomeDirectoryAbbreviatesToWhateverTheCallerStandsItFor() {
    #expect("/Users/me/x".abbreviatingHomeDirectory(home: "/Users/me", as: "$HOME") == "$HOME/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me", as: "$HOME") == "$HOME")
    #expect("/Users/me/Work/x".abbreviatingHomeDirectory(home: "/Users/me") == "~/Work/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me") == "~")
    #expect("/Users/meg/x".abbreviatingHomeDirectory(home: "/Users/me") == "/Users/meg/x")
    #expect("/tmp/x".abbreviatingHomeDirectory(home: "/Users/me") == "/tmp/x")
  }

  @Test func aNeighbourWrapsAtBothEndsAndAnArrayOfOneHasNone() {
    struct Item: Identifiable { let id: Int }
    let items = [Item(id: 1), Item(id: 2), Item(id: 3)]
    #expect(items.neighbour(of: 3, .after)?.id == 1)
    #expect(items.neighbour(of: 1, .before)?.id == 3)
    #expect(items.neighbour(of: 2, .after)?.id == 3)
    #expect(items.neighbour(of: 9, .after) == nil)
    #expect([Item(id: 1)].neighbour(of: 1, .after) == nil)
  }

  @Test func clampedHoldsAValueInsideTheRange() {
    #expect(5.clamped(to: 0...3) == 3)
    #expect((-1).clamped(to: 0...3) == 0)
    #expect(2.5.clamped(to: 0...3) == 2.5)
  }
}
