import Testing

@testable import MultishellServices

@Suite
struct GitHubJobLogTests {
  @Test func eachLineLosesItsTimestampAndItsColour() {
    let output =
      "2026-11-19T01:02:03.4567890Z \u{1b}[31merror:\u{1b}[0m boom\n"
      + "2026-11-19T01:02:04.0000000Z   at App.swift:12"

    #expect(
      GitHubJobLog.log(from: output, keepingLast: 160).text == "error: boom\n  at App.swift:12"
    )
  }

  @Test func aLineWithoutATimestampIsKeptAsItIs() {
    #expect(GitHubJobLog.log(from: "plain\tline", keepingLast: 160).text == "plain\tline")
  }

  @Test func aStepsFirstLineLosesItsByteOrderMarkAndTimestamp() {
    let output = "\u{FEFF}2026-11-19T01:02:03.4567890Z ##[group]Run tests"

    #expect(GitHubJobLog.log(from: output, keepingLast: 160).text == "Run tests")
  }

  @Test func otherControlCodesAndGroupMarkersAreStrippedToo() {
    let output =
      "2026-11-19T01:02:03.4Z ##[group]Run tests\n"
      + "2026-11-19T01:02:03.5Z \u{1b}[Kbuilding\u{1b}[?25l\n"
      + "2026-11-19T01:02:03.6Z ##[endgroup]"

    #expect(GitHubJobLog.log(from: output, keepingLast: 160).text == "Run tests\nbuilding")
  }

  @Test func onlyTheLastLinesAskedForAreCleanedAndTheRestCounted() {
    let output = (1...5).map { "2026-11-19T01:02:03.4Z line \($0)" }.joined(separator: "\n")

    let log = GitHubJobLog.log(from: output, keepingLast: 2)

    #expect(log.text == "line 4\nline 5")
    #expect(log.earlierLineCount == 3)
  }

  @Test func carriageReturnsInsideALineDoNotSkewTheEarlierCount() {
    let plain = (1...10).map { "2026-11-19T01:02:03.4Z line \($0)" }
    let progress = (1...3).map { _ in "2026-11-19T01:02:03.4Z 10%\r50%\r100%" }
    let output = (plain + progress).joined(separator: "\n")

    let log = GitHubJobLog.log(from: output, keepingLast: 2)

    #expect(log.text == "10%\r50%\r100%\n10%\r50%\r100%")
    #expect(log.earlierLineCount == 11)
  }

  @Test func anEndGroupMarkerTakesNoLineOfTheTail() {
    let output =
      "2026-11-19T01:02:03.4Z error: boom\n"
      + "2026-11-19T01:02:03.5Z ##[endgroup]"

    #expect(GitHubJobLog.log(from: output, keepingLast: 160).text == "error: boom")
  }

  @Test func aFoldEndDroppedFromTheTailIsCountedAmongTheLinesCut() {
    let output =
      "2026-11-19T01:02:03.1Z one\n"
      + "2026-11-19T01:02:03.2Z two\n"
      + "2026-11-19T01:02:03.3Z three\n"
      + "2026-11-19T01:02:03.4Z ##[endgroup]\n"
      + "2026-11-19T01:02:03.5Z four"

    let log = GitHubJobLog.log(from: output, keepingLast: 3)

    #expect(log.text == "three\nfour")
    #expect(log.earlierLineCount == 3)
  }

  @Test func theRunnersCleanupAfterTheLastErrorLineIsLeftOut() {
    let output =
      "2026-11-19T01:02:03.1Z ##[error]first\n"
      + "2026-11-19T01:02:03.2Z make: *** [lint] Error 2\n"
      + "2026-11-19T01:02:03.3Z ##[error]Process completed with exit code 2.\n"
      + "2026-11-19T01:02:03.4Z Post job cleanup.\n"
      + "2026-11-19T01:02:03.5Z Cleaning up orphan processes"

    let log = GitHubJobLog.log(from: output, keepingLast: 2)

    #expect(log.text == "make: *** [lint] Error 2\n##[error]Process completed with exit code 2.")
    #expect(log.earlierLineCount == 1)
  }
}
