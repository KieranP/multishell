import Testing

@testable import MultishellGitKit

@Suite
struct TrackedFileListParserTests {
  private static func record(
    _ tag: String,
    _ mode: String,
    _ path: String,
    stage: Int = 0,
  ) -> String {
    "\(tag) \(mode) d00491fd7e5bb6fa28c517a0bb32b8b506539d4d \(stage)\t\(path)\0"
  }

  @Test func aConflictedPathListedOnceAStageIsKeptOnce() {
    let output = (1...3).map { Self.record("M", "100644", "both.txt", stage: $0) }.joined()

    #expect(TrackedFileListParser.parse(output, limit: 10).paths == ["both.txt"])
  }

  @Test func aGitlinkIsASubmodule() {
    let output = Self.record("H", "160000", "vendor/lib") + Self.record("H", "100644", "a.txt")

    #expect(TrackedFileListParser.parse(output, limit: 10).submodulePaths == ["vendor/lib"])
  }

  @Test func pathsPastTheLimitAreLeftOutAndSaySo() {
    let output = ["a", "b", "c"].map { Self.record("H", "100644", $0) }.joined()

    let tracked = TrackedFileListParser.parse(output, limit: 2)

    #expect(tracked.paths == ["a", "b"])
    #expect(tracked.isCapped)
  }

  @Test func aPathASparseCheckoutLeavesOutIsMarkedNotCheckedOut() {
    let output = Self.record("H", "100644", "a/x") + Self.record("S", "100644", "b/y")

    let tracked = TrackedFileListParser.parse(output, limit: 10)

    #expect(tracked.paths == ["a/x", "b/y"])
    #expect(tracked.notCheckedOutPaths == ["b/y"])
  }
}
