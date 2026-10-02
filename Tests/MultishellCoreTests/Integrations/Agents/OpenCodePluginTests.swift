import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The plugin's 70 lines of state are out of Swift's reach, so these run it under node
/// with `spawn` replaced and read the argument lists back.
@Suite(.serialized, .enabled(if: openCodeNode != nil))
struct OpenCodePluginTests: OpenCodePluginDriver {
  /// Two report processes can land in either order: a cancelled child's end after
  /// the Done that left it out put it back on the roster for good.
  @Test func eachReportIsSentOnlyOnceTheOneBeforeItHasExited() throws {
    let lines = try run([
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .error("parent/a", name: "MessageAbortedError"),
      .idle("parent"),
    ]).lines.filter { !$0.contains("waits") }
    #expect(lines.count == 8)
    #expect(
      lines.enumerated().allSatisfy { index, line in (index % 2 == 1) == line.contains("exited") },
      "\(lines)")
  }

  /// A helper that hangs holds each report two seconds, so a burst of tool
  /// calls would queue minutes of reports that all say the same thing.
  @Test func aRunOfPlainWorkingReportsWaitingToBeSentIsSentOnce() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .tool(session: "parent"), .tool(session: "parent"), .tool(session: "parent"),
      .tool(session: "parent"), .idle("parent"),
    ])
    #expect(out.map(said) == ["running true", "running", "done"])
    #expect(out.map(said).last == "done")
  }

  @Test func theParentsDoneSaysItResumesAndListsTheChildrenStillBusy() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .idle("parent/b"),
      .idle("parent"),
    ])
    let done = try #require(out.last)
    #expect(value(done, "--resumes") == "true")
    #expect(value(done, "--out") == "parent/a")
  }

  @Test func theParentsDoneWithNoChildOutListsNone() throws {
    let out = try reports(of: [.message(session: "parent"), .idle("parent")])
    #expect(value(try #require(out.last), "--out") == "")
  }

  @Test func anAbortedChildsEndWakesNoTurnAndAFailedOnesDoes() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .error("parent/a", name: "MessageAbortedError"),
      .error("parent/b", name: "UnknownError"),
    ])
    let ends = out.filter { value($0, "--subagent-phase") == "ended" }
    #expect(ends.map { value($0, "--subagent-wakes") } == ["false", nil])
  }

  @Test func aPromptOfOnlySyntheticPartsIsTheWokenTurnNotANewOne() throws {
    let out = try reports(of: [
      .message(session: "parent"), .idle("parent"), .synthetic(session: "parent"),
    ])
    #expect(out.map(said) == ["running true", "done", "running"])
  }

  @Test func aPromptInTheParentStartsATurnAndOneInAChildIsItsWork() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .tool(session: "parent/a"),
      .idle("parent/a"),
      .idle("parent"),
    ])
    #expect(
      out.map(said) == [
        "running true", "running started Explore", "running working Explore",
        "running ended Explore", "done",
      ])
  }

  @Test func aTurnsEndInBothSpellingsIsReportedOnce() throws {
    let idleStatus = OpenCodePluginStep.event(
      "session.status",
      ["sessionID": AnyEncodable("parent"), "status": AnyEncodable(["type": "idle"])])
    let out = try reports(of: [
      .message(session: "parent"), idleStatus, .idle("parent"),
      .message(session: "parent"), .idle("parent"), idleStatus,
    ])
    #expect(out.map(said) == ["running true", "done", "running true", "done"])
  }

  @Test func aParentTurnWithNoPromptStillEndsInADone() throws {
    let out = try reports(of: [
      .message(session: "parent"), .idle("parent"), .busy("parent"), .idle("parent"),
    ])
    #expect(out.map(said) == ["running true", "done", "done"])
  }

  /// OpenCode hands `chat.message` the message as its second argument, so a session named
  /// only there still has to be read, or every child's message starts the parent's turn.
  @Test func aChildsMessageInTheSecondArgumentStartsNoTurnOfTheParents() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .message(session: "parent/a", inSecondArgument: true),
      .idle("parent"),
      .idle("parent/a"),
    ])
    #expect(
      out.map(said) == [
        "running true", "running started Explore", "running working Explore", "done",
        "running ended Explore",
      ],
      "the child's message is its work, not a turn of the parent's")
  }

  /// A hook that names no session at all: before the roster it cost nothing,
  /// and it must still cost nothing rather than clear what is out.
  @Test func aMessageNamingNoSessionStartsNoTurn() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .message(session: nil),
      .idle("parent/a"),
    ])
    #expect(
      out.map(said) == [
        "running true", "running started Explore", "running", "running ended Explore",
      ])
  }

  @Test func aPermissionAskedInsideAChildIsThatWorkersPrompt() throws {
    let out = try reports(of: [
      .created(child: "a", of: "parent", agent: "Plan"),
      .asked("parent/a", permission: "bash", pattern: "echo hi"),
    ])
    #expect(out.map(said) == ["running started Plan", "attention working Plan bash echo hi"])
  }

  /// A child's id outlives its end, so a late event of its own is not read as
  /// the parent's Done.
  @Test func anEventAfterAChildHasEndedReportsNothing() throws {
    let out = try reports(of: [
      .created(child: "a", of: "parent", agent: "Explore"),
      .idle("parent/a"),
      .idle("parent/a"),
      .tool(session: "parent/a"),
    ])
    #expect(out.map(said) == ["running started Explore", "running ended Explore"])
  }

  /// With more than one place, the cycling child would push another's id out, and that
  /// child's late event would read as the parent's Done.
  @Test func aChildCyclingBusyAndIdleKeepsOnePlaceAmongTheEndedIds() throws {
    var steps: [OpenCodePluginStep] = [
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .idle("parent/b"),
    ]
    for _ in 0..<70 {
      steps.append(.busy("parent/a"))
      steps.append(.idle("parent/a"))
    }
    steps.append(.idle("parent/b"))

    let out = try reports(of: steps).map(said)
    #expect(out.last == "running ended Explore", "b's late idle says nothing")
    #expect(!out.contains("done"), "and is not read as the parent's Done")
  }

  /// A task resumed by its id reuses its session and publishes no `session.created`
  /// (opencode `tool/task.ts`), so a plugin that has lost the id must ask for it.
  @Test func aResumedChildsFirstMessageStartsNoTurnOfTheParents() throws {
    let out = try reports(
      of: [.message(session: "parent"), .message(session: "parent/a"), .idle("parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent"]])
    #expect(
      out.map(said) == [
        "running true", "running started", "running working", "running ended",
      ])
  }

  @Test func aLookupThatFailsLeavesTheSessionTheParents() throws {
    let out = try reports(
      of: [.message(session: "parent"), .idle("parent")],
      sessions: ["parent": ["throws": "true"]])
    #expect(out.map(said) == ["running true", "done"])
  }

  @Test(arguments: [[:], ["parent": ["hangs": "true"]]])
  func theParentIsLookedUpOnceHoweverTheLookupEnds(sessions: [String: [String: String]]) throws {
    let out = try run(
      [
        .message(session: "parent"), .tool(session: "parent"), .tool(session: "parent"),
        .idle("parent"),
      ],
      sessions: sessions)
    #expect(out.reports.map(said) == ["running true", "running", "done"], "the second collapses")
    #expect(out.waits == 1)
  }

  @Test func aChildWhoseLookupAnswersAfterTheBoundIsPutBackWhenItLands() throws {
    let out = try reports(
      of: [.message(session: "parent/a"), .pause, .idle("parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent", "late": "true"]])
    #expect(out.map(said) == ["running true", "running started", "running ended"])
  }

  @Test func aChildPutBackByALookupIsNotStartedAgainByALateCreation() throws {
    let out = try reports(
      of: [
        .message(session: "parent/a"), .created(child: "a", of: "parent", agent: "Explore"),
        .idle("parent/a"),
      ],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent"]])
    #expect(out.map(said) == ["running started", "running working", "running ended"])
  }
}
