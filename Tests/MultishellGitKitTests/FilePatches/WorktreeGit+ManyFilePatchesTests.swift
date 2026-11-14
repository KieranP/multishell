import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeGitManyFilePatchesTests {
  @Test func manyFilesInOneRunGiveEachFileThePatchesItsOwnRunGives() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("a", file: "a.txt", content: "one\ntwo\n")
    try await fixture.commit("b", file: "docs/b c.txt", content: "x\ny\n")
    try await fixture.commit("c", file: "c.txt", content: "same\n")
    let root = fixture.project.path
    try "one\nTWO\n".write(to: root.appending(path: "a.txt"), atomically: true, encoding: .utf8)
    try "x\nY\nz\n".write(
      to: root.appending(path: "docs/b c.txt"),
      atomically: true,
      encoding: .utf8,
    )
    let git = fixture.git
    let paths = ["a.txt", "docs/b c.txt", "c.txt"]

    let many = try #require(
      await git.patches(
        ofMany: paths,
        in: root,
        diffAlgorithm: .histogram,
        since: nil,
        base: "HEAD",
      )
    )

    for path in paths {
      let alone = try #require(await git.patches(of: path, in: root, diffAlgorithm: .histogram))
      #expect(many[path]?.onDisk == alone.onDisk, "\(path)")
      #expect(many[path]?.staged == alone.staged, "\(path)")
    }
  }

  @Test func aFileReplacedByALinkGivesBothItsPatchesAsItsOwnRunDoes() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("a", file: "a.txt", content: "one\n")
    try await fixture.commit("b", file: "b.txt", content: "two\n")
    let root = fixture.project.path
    try FileManager.default.removeItem(at: root.appending(path: "a.txt"))
    try FileManager.default.createSymbolicLink(
      atPath: root.appending(path: "a.txt").path,
      withDestinationPath: "b.txt",
    )
    let git = fixture.git

    let many = try #require(
      await git.patches(
        ofMany: ["a.txt"],
        in: root,
        diffAlgorithm: .histogram,
        since: nil,
        base: "HEAD",
      )
    )

    let alone = try #require(await git.patches(of: "a.txt", in: root, diffAlgorithm: .histogram))
    #expect(many["a.txt"]?.onDisk == alone.onDisk)
  }

  @Test func aNameWithAnAccentIsDiffedInItsChunkNotReadAlone() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("a", file: "café.txt", content: "one\n")
    let root = fixture.project.path
    try "two\n".write(to: root.appending(path: "café.txt"), atomically: true, encoding: .utf8)

    let many = await fixture.git.patches(
      ofMany: ["café.txt"],
      in: root,
      diffAlgorithm: .histogram,
      since: nil,
      base: "HEAD",
    )

    #expect(many?["café.txt"] != nil)
  }
}
