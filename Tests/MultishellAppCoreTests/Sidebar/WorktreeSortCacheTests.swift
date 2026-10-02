import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeSortCacheTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)

  private func worktree(_ branch: String) -> Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/w/t/\(branch)"), projectID: project.id, head: "0",
      branch: branch)
  }

  private func keys(_ names: [String], in rule: WorktreeSortRule? = nil) -> [WorktreeSortRule.Key] {
    (rule ?? self.rule).keys(
      names.map(worktree), displayName: { $0.name }, isActive: { _ in false },
      lastCommit: { _ in nil })
  }

  @Test func aRebuildWithTheSameRowsSortsNothing() {
    var cache = WorktreeSortCache()

    let first = cache.rows(of: project.id, keys: keys(["zulu", "alpha"]), rule: rule)
    let second = cache.rows(of: project.id, keys: keys(["zulu", "alpha"]), rule: rule)

    #expect(first.map(\.name) == ["alpha", "zulu"])
    #expect(second == first)
    #expect(cache.sortCount == 1)
  }

  @Test func aRenamedRowOrADifferentRuleSortsAgain() {
    var cache = WorktreeSortCache()
    let newest = WorktreeSortRule(sortOrder: .createdNewestFirst, showsActiveFirst: false)

    _ = cache.rows(of: project.id, keys: keys(["zulu", "alpha"]), rule: rule)
    let renamed = cache.rows(of: project.id, keys: keys(["zulu", "beta"]), rule: rule)
    _ = cache.rows(of: project.id, keys: keys(["zulu", "beta"], in: newest), rule: newest)

    #expect(renamed.map(\.name) == ["beta", "zulu"])
    #expect(cache.sortCount == 3)
  }

  @Test func eachProjectKeepsItsOwnOrder() {
    var cache = WorktreeSortCache()
    let other = Project(path: URL(fileURLWithPath: "/w/other"))

    _ = cache.rows(of: project.id, keys: keys(["b", "a"]), rule: rule)
    _ = cache.rows(of: other.id, keys: keys(["d", "c"]), rule: rule)
    let again = cache.rows(of: project.id, keys: keys(["b", "a"]), rule: rule)

    #expect(again.map(\.name) == ["a", "b"])
    #expect(cache.sortCount == 2)
  }
}
