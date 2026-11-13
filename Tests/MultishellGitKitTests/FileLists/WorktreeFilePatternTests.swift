import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
final class WorktreeFilePatternTests {
  private let root = Scratch.path("patterns")

  @Test func patternsMatchWithinOneNameOnly() {
    #expect(WorktreeFilePattern.matches(".env.local", pattern: ".env.*"))
    #expect(WorktreeFilePattern.matches(".env.", pattern: ".env.*"), "`*` may take nothing")
    #expect(!WorktreeFilePattern.matches(".env", pattern: ".env.*"))
    #expect(WorktreeFilePattern.matches("a.json", pattern: "*.json"))
    #expect(!WorktreeFilePattern.matches("a.json.bak", pattern: "*.json"))
    #expect(WorktreeFilePattern.matches("config.yml", pattern: "config.???"))
    #expect(!WorktreeFilePattern.matches("config.yaml", pattern: "config.???"))
    #expect(WorktreeFilePattern.matches("aXbXc", pattern: "a*b*c"), "backtracks over both stars")
    #expect(!WorktreeFilePattern.matches("aXbXd", pattern: "a*b*c"))
    #expect(WorktreeFilePattern.matches("anything", pattern: "*"))
    #expect(WorktreeFilePattern.matches("", pattern: "*"))
  }

  @Test func aStarStillMatchesWhereTheNameHoldsAStarOfItsOwn() {
    #expect(WorktreeFilePattern.matches("*x", pattern: "*"))
    #expect(WorktreeFilePattern.matches("a*b", pattern: "a*"))
    #expect(WorktreeFilePattern.matches("a*b*c", pattern: "a*c"))
  }

  @Test func aNameStoredDecomposedMatchesAPatternTypedPrecomposed() {
    #expect(
      WorktreeFilePattern.matches("Re\u{0301}sume\u{0301}.pdf", pattern: "R\u{e9}sum\u{e9}*")
    )
  }

  /// `*` taking `.git` with it would copy a repository into a worktree.
  @Test func aPatternTakesAHiddenNameOnlyWhenItSpellsTheDot() {
    #expect(!WorktreeFilePattern.matches(".git", pattern: "*"))
    #expect(!WorktreeFilePattern.matches(".env", pattern: "*env"))
    #expect(WorktreeFilePattern.matches(".env", pattern: ".*"))
    #expect(WorktreeFilePattern.matches(".env.local", pattern: ".env.*"))
    #expect(!WorktreeFilePattern.matches(".\u{0301}env", pattern: "*"), "a mark after the dot")
    #expect(WorktreeFilePattern.matches(".\u{0301}env", pattern: ".*"))
  }

  @Test func aPatternStandsForTheNamesItMatchesAndAPlainPathForItself() throws {
    let repository = root.appendingPathComponent("repo")
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    for name in [".env.local", ".env.test", ".env", "notes.md", ".git"] {
      try "x".write(to: repository.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    #expect(WorktreeFilePattern.expand(".env.*", in: repository) == [".env.local", ".env.test"])
    #expect(WorktreeFilePattern.expand("*", in: repository) == ["notes.md"], "no hidden names")
    #expect(WorktreeFilePattern.expand("nothing.*", in: repository).isEmpty)
    #expect(
      WorktreeFilePattern.expand("missing/file", in: repository) == ["missing/file"],
      "a plain path is itself, whether it is there or not",
    )
  }

  @Test func aPatternInAFolderNameExpandsToEachFolderThatMatches() throws {
    let repository = root.appendingPathComponent("repo")
    for pack in ["pack-a", "pack-b"] {
      try FileManager.default.createDirectory(
        at: repository.appendingPathComponent(pack),
        withIntermediateDirectories: true,
      )
      try "x".write(
        to: repository.appendingPathComponent("\(pack)/.env"),
        atomically: true,
        encoding: .utf8,
      )
    }
    #expect(
      WorktreeFilePattern.expand("pack-?/.env", in: repository) == ["pack-a/.env", "pack-b/.env"]
    )
  }

  deinit { Scratch.remove(root) }
}
