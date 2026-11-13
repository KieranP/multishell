import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ReviewFileTests {
  private static let worktree = "/repos/demo/feature"

  private static func comment(_ text: String = "Guard it.") -> ReviewComment {
    ReviewComment(
      path: "Sources/App.swift",
      side: .onDisk,
      scope: .modified,
      lines: 3...4,
      quote: ["let a = 1", "let b = 2"],
      text: text,
    )
  }

  @Test func savedCommentsLoadBackAsWritten() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)
    var sent = Self.comment("Sent one")
    sent.state = .sent(agentName: "Claude Code", at: Date(timeIntervalSince1970: 1_000))
    let comments = [Self.comment(), sent]

    try file.save(comments, as: file.issueTicket())

    #expect(try ReviewFile(worktreeID: Self.worktree, in: directory).load() == comments)
  }

  @Test func eachWorktreeReadsOnlyItsOwnFile() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)

    try file.save([Self.comment()], as: file.issueTicket())

    #expect(try ReviewFile(worktreeID: "/repos/demo/other", in: directory).load().isEmpty)
  }

  @Test func savingNoCommentsRemovesTheFile() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)
    try file.save([Self.comment()], as: file.issueTicket())

    try file.save([], as: file.issueTicket())

    let left = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(left.isEmpty)
  }

  @Test func aCommentInAStateThisBuildCannotReadCostsThatCommentAlone() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)
    try file.save([Self.comment("first"), Self.comment("second")], as: file.issueTicket())
    let written = try #require(
      try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .first
    )
    let text = try String(contentsOf: written, encoding: .utf8)
    let edited = text.replacingOccurrences(
      of: #""pending" : {"#,
      with: #""archived" : {"#,
      options: [],
      range: text.range(of: #""pending" : {"#),
    )
    try edited.write(to: written, atomically: true, encoding: .utf8)

    #expect(try file.load().map(\.text) == ["second"])
  }

  @Test func anUnreadableFileIsMovedAsideRatherThanLoadedEmptyAndOverwritten() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)
    try file.save([Self.comment()], as: file.issueTicket())
    let written = try #require(
      try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .first
    )
    try "not json".write(to: written, atomically: true, encoding: .utf8)

    #expect(throws: UnreadableReviewFile.self) { try file.load() }

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(names.count == 1)
    #expect(names.allSatisfy { $0.hasSuffix(".broken.json") })
  }

  @Test func aFileThatCannotBeReadIsMovedAsideRatherThanWrittenOver() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)
    try file.save([Self.comment()], as: file.issueTicket())
    let name = try #require(
      try FileManager.default.contentsOfDirectory(atPath: directory.path).first
    )
    let path = directory.appendingPathComponent(name).path
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: path)

    #expect(throws: UnreadableReviewFile.self) { try file.load() }

    #expect(!file.exists)
  }

  @Test func aSecondBrokenFileIsSetAsideBesideTheFirst() throws {
    let directory = Scratch.path("reviews")
    defer { Scratch.remove(directory) }
    let file = ReviewFile(worktreeID: Self.worktree, in: directory)
    for _ in 0..<2 {
      try file.save([Self.comment()], as: file.issueTicket())
      let name = try #require(
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
          .first { !$0.hasSuffix(".broken.json") }
      )
      try Data("not json".utf8).write(to: directory.appendingPathComponent(name))
      _ = try? file.load()
    }

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(names.count { $0.hasSuffix(".broken.json") } == 2)
  }
}
