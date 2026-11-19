import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestHandoffTests {
  private static let link = URL(string: "https://github.com/me/demo/actions/runs/7/job/9")!

  private static func checkItem() -> PullRequestHandoffItem {
    .check(.sample(name: "test", status: .failed, link: link), headCommit: "abc1234def")
  }

  @Test func aCheckQuotesItsLogsTailAndLinksItsPage() {
    let item = Self.checkItem()

    let entry = PullRequestHandoff.entries(
      of: [item],
      logs: [item.candidate.id: .read(FailedCheckLog(text: "error: boom", earlierLineCount: 0))],
      localTip: "abc1234def",
    )[0]

    #expect(entry.heading == "CI / test")
    #expect(entry.quote == ["error: boom"])
    #expect(entry.caveat == nil)
    #expect(entry.text == "Failed. Its page: \(Self.link.absoluteString)")
  }

  @Test func aLogThatFailedToReadIsSentWithTheToolsWords() {
    let item = Self.checkItem()

    let entry = PullRequestHandoff.entries(
      of: [item],
      logs: [item.candidate.id: .failed("HTTP 404")],
      localTip: nil,
    )[0]

    #expect(entry.quote.isEmpty)
    #expect(entry.caveat == "Its log could not be read: HTTP 404")
  }

  @Test func aWorktreeOnAnotherCommitIsToldWhichCommitTheCheckRanOn() {
    let item = Self.checkItem()

    let entry = PullRequestHandoff.entries(of: [item], logs: [:], localTip: "fff0000")[0]

    #expect(entry.caveat?.contains("abc1234") == true)
  }

  @Test func aThreadIsHeadedByItsPlaceAndQuotesTheEndOfItsHunk() {
    let thread = PullRequestThread.sample(comments: ["Guard it.", "Agreed."])

    let entry = PullRequestHandoff.entries(of: [.thread(thread)], logs: [:], localTip: nil)[0]

    #expect(entry.heading == "Sources/App.swift:12")
    #expect(entry.quote == ["@@ -1,2 +1,2 @@", "-let a", "+let b"])
    #expect(entry.text.hasPrefix("jt: Guard it.\n\njt: Agreed."))
  }

  @Test func anOutdatedThreadIsLabelledByTheLineItWasWrittenOnAndSaysSo() {
    let thread = PullRequestThread.sample(line: nil, originalLine: 10, isOutdated: true)

    let entry = PullRequestHandoff.entries(of: [.thread(thread)], logs: [:], localTip: nil)[0]

    #expect(entry.heading == "Sources/App.swift:10")
    #expect(entry.caveat == "Outdated: the lines it was written on have changed since.")
  }

  @Test func aWorktreeOnAnotherCommitIsToldSoWithoutClaimingItIsAhead() {
    let item = Self.checkItem()

    let entry = PullRequestHandoff.entries(of: [item], logs: [:], localTip: "fff0000aaa")[0]

    #expect(entry.caveat == "This ran on abc1234, not the worktree's current commit.")
  }

  @Test func aThreadOnACRLFFileQuotesItsHunkWithoutCarriageReturns() {
    let thread = PullRequestThread.sample(hunk: "@@ -1 +1 @@\r\n-let a\r\n+let b")

    let entry = PullRequestHandoff.entries(of: [.thread(thread)], logs: [:], localTip: nil)[0]

    #expect(entry.quote == ["@@ -1 +1 @@", "-let a", "+let b"])
  }

  @Test func aLogThatPrintedNothingSaysSo() {
    let item = Self.checkItem()

    let entry = PullRequestHandoff.entries(
      of: [item],
      logs: [item.candidate.id: .read(FailedCheckLog(text: "", earlierLineCount: 0))],
      localTip: nil,
    )[0]

    #expect(entry.caveat == "Its log printed nothing.")
  }

  @Test func aThreadWithNoHunkQuotesNothing() {
    let thread = PullRequestThread.sample(hunk: "")

    let entry = PullRequestHandoff.entries(of: [.thread(thread)], logs: [:], localTip: nil)[0]

    #expect(entry.quote.isEmpty)
  }

  @Test func aLongLogSaysHowManyLinesCameBeforeItsTailInTheWholeLog() {
    let output = (1...12_000).map { "test\tRun\t2026-11-19T01:02:03.4Z line \($0)" }
      .joined(separator: "\n")
    let log = GitHubJobLog.log(from: output, keepingLast: HandoffLogTail.linesToRead)
    let item = Self.checkItem()

    let entry = PullRequestHandoff.entries(
      of: [item],
      logs: [item.candidate.id: .read(log)],
      localTip: nil,
    )[0]

    #expect(entry.caveat == "11920 earlier lines cut.")
  }
}
