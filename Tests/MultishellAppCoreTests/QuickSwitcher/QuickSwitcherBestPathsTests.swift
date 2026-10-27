import Testing

@testable import MultishellAppCore

@Suite
struct QuickSwitcherBestPathsTests {
  @Test func keepsTheHighestScoresBestFirstUpToTheLimit() {
    var best = QuickSwitcherBestPaths(limit: 2)

    for (path, score) in [("a", 1), ("b", 5), ("c", 3), ("d", 4)] {
      best.offer(path, score: score)
    }

    #expect(best.paths == ["b", "d"])
  }

  @Test func equalScoresKeepPathOrderWhicheverArrivesFirst() {
    var best = QuickSwitcherBestPaths(limit: 2)

    for path in ["c", "a", "b"] {
      best.offer(path, score: 1)
    }

    #expect(best.paths == ["a", "b"])
  }

  @Test func aPathOfferedTwiceIsKeptOnce() {
    var best = QuickSwitcherBestPaths(limit: 3)

    for path in ["a", "b", "a"] {
      best.offer(path, score: 0)
    }

    #expect(best.paths == ["a", "b"])
  }
}
