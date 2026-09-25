import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOrderMemoTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let order = WorktreeOrder(sortOrder: .alphabetical, activeFirst: false)

  private func worktree(_ branch: String) -> Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/w/t/\(branch)"), projectID: project.id, head: "0",
      branch: branch)
  }

  private func keys(_ names: [String], in order: WorktreeOrder? = nil) -> [WorktreeOrder.Key] {
    (order ?? self.order).keys(
      names.map(worktree), displayName: { $0.name }, isActive: { _ in false },
      lastCommit: { _ in nil })
  }

  @Test func aRebuildWithTheSameRowsSortsNothing() {
    var memo = WorktreeOrderMemo()

    let first = memo.rows(of: project.id, keys: keys(["zulu", "alpha"]), order: order)
    let second = memo.rows(of: project.id, keys: keys(["zulu", "alpha"]), order: order)

    #expect(first.map(\.name) == ["alpha", "zulu"])
    #expect(second == first)
    #expect(memo.sorts == 1)
  }

  @Test func aRenamedRowOrADifferentRuleSortsAgain() {
    var memo = WorktreeOrderMemo()
    let newest = WorktreeOrder(sortOrder: .createdNewestFirst, activeFirst: false)

    _ = memo.rows(of: project.id, keys: keys(["zulu", "alpha"]), order: order)
    let renamed = memo.rows(of: project.id, keys: keys(["zulu", "beta"]), order: order)
    _ = memo.rows(of: project.id, keys: keys(["zulu", "beta"], in: newest), order: newest)

    #expect(renamed.map(\.name) == ["beta", "zulu"])
    #expect(memo.sorts == 3)
  }

  @Test func eachProjectKeepsItsOwnOrder() {
    var memo = WorktreeOrderMemo()
    let other = Project(path: URL(fileURLWithPath: "/w/other"))

    _ = memo.rows(of: project.id, keys: keys(["b", "a"]), order: order)
    _ = memo.rows(of: other.id, keys: keys(["d", "c"]), order: order)
    let again = memo.rows(of: project.id, keys: keys(["b", "a"]), order: order)

    #expect(again.map(\.name) == ["a", "b"])
    #expect(memo.sorts == 2)
  }
}
