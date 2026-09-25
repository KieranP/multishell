import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
final class WorktreeFilePatternTests {
  private let root = Scratch.path("patterns")

  deinit { Scratch.remove(root) }

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

  /// `*` taking `.git` with it would copy a repository into a worktree.
  @Test func aPatternTakesAHiddenNameOnlyWhenItSpellsTheDot() {
    #expect(!WorktreeFilePattern.matches(".git", pattern: "*"))
    #expect(!WorktreeFilePattern.matches(".env", pattern: "*env"))
    #expect(WorktreeFilePattern.matches(".env", pattern: ".*"))
    #expect(WorktreeFilePattern.matches(".env.local", pattern: ".env.*"))
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
      "a plain path is itself, whether it is there or not")
  }
}
