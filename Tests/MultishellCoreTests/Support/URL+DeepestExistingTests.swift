import Foundation
import Testing

@testable import MultishellCore

@Suite
struct URLDeepestExistingTests {
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
}
