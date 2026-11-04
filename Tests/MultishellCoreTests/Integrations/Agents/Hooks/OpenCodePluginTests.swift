import Foundation
import Testing

@testable import MultishellCore

/// The plugin's state is out of Swift's reach, so these run its `setup` under
/// node against a fake context, with `spawn` replaced.
@Suite(.serialized, .enabled(if: openCodeNode != nil))
struct OpenCodePluginTests: OpenCodePluginDriver {
  /// Two report processes can land in either order: a cancelled child's end after
  /// the Done that left it out put it back on the roster for good.
  @Test func eachReportIsSentOnlyOnceTheOneBeforeItHasExited() throws {
    let lines = try run([
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .interrupted("parent/a", reason: "user"),
      .succeeded("parent"),
    ]).lines.filter { !$0.contains("lookups") }
    #expect(lines.count == 8)
    #expect(
      lines.enumerated().allSatisfy { index, line in (index % 2 == 1) == line.contains("exited") },
      "\(lines)",
    )
  }

  /// A helper that hangs holds each report two seconds, so a burst of tool
  /// calls would queue minutes of reports that all say the same thing.
  @Test func aRunOfPlainWorkingReportsWaitingToBeSentIsSentOnce() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .tool(session: "parent"), .tool(session: "parent"), .tool(session: "parent"),
      .tool(session: "parent"), .succeeded("parent"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "running", "done"])
  }

  @Test func aWorkingQueuedBeforeAPromptDoesNotSwallowTheReplysWorking() throws {
    let out = try reports(of: [
      .message(session: "p"), .tool(session: "p"),
      .asked("p", action: "edit", resource: "f"), .replied("p"),
    ])
    #expect(
      out.map(chipSummary(of:)) == ["running true", "running", "attention edit f", "running"]
    )
  }

  @Test func aParentsAndChildsToolCallsInTurnQueueOneWorkingEach() throws {
    var steps: [OpenCodePluginStep] = [
      .message(session: "p"), .created(child: "c", of: "p", agent: "Explore"),
    ]
    for _ in 0..<4 { steps += [.tool(session: "p"), .tool(session: "p/c")] }
    steps.append(.succeeded("p"))
    #expect(
      try reports(of: steps).map(chipSummary(of:)) == [
        "running true", "running started Explore", "running", "running working Explore", "done",
      ]
    )
  }

  @Test func theParentsDoneSaysItResumesAndListsTheChildrenStillRunning() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .succeeded("parent/b"),
      .succeeded("parent"),
    ])
    let done = try #require(out.last)
    #expect(flagValue(done, "--resumes") == "true")
    #expect(flagValue(done, "--out") == "parent/a")
  }

  @Test func theParentsDoneWithNoChildOutListsNone() throws {
    let out = try reports(of: [.message(session: "parent"), .succeeded("parent")])
    #expect(flagValue(try #require(out.last), "--out") == "")
  }

  /// OpenCode hands the parent a cancelled child's end as a message of its
  /// own, so that end wakes it as a finished one does.
  @Test func aChildTheUserInterruptedEndsAsAFailedOneDoesAndTheParentsWokenTurnEnds() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .succeeded("parent"),
      .interrupted("parent/a", reason: "user"),
      .failed("parent/b"),
      .started("parent"), .succeeded("parent"),
    ])
    let ends = out.filter { flagValue($0, "--subagent-phase") == "ended" }
    #expect(ends.map { flagValue($0, "--subagent") } == ["parent/a", "parent/b"])
    #expect(ends.allSatisfy { flagValue($0, "--subagent-wakes") == nil })
    #expect(out.suffix(2).map(chipSummary(of:)) == ["running", "done"])
    #expect(flagValue(try #require(out.last), "--out") == "")
  }

  @Test func aTurnStartedWithNoPromptIsTheWokenTurnNotANewOne() throws {
    let out = try reports(of: [
      .message(session: "parent"), .started("parent"), .succeeded("parent"),
      .started("parent"), .succeeded("parent"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "done", "running", "done"])
  }

  @Test func aPromptInTheParentStartsATurnAndAToolCallInAChildIsItsWork() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .tool(session: "parent/a"),
      .succeeded("parent/a"),
      .succeeded("parent"),
    ])
    #expect(
      out.map(chipSummary(of:)) == [
        "running true", "running started Explore", "running working Explore",
        "running ended Explore", "done",
      ]
    )
  }

  @Test func aFailedTurnIsAnErrorAndOneTheUserInterruptedIsIdle() throws {
    let out = try reports(of: [
      .message(session: "parent"), .failed("parent"),
      .message(session: "parent"), .interrupted("parent", reason: "user"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "error expired", "running true", "idle"])
  }

  /// A prompt sent while a turn runs supersedes that turn's execution, and the
  /// new one carries on: idle there would clear a pane still working.
  @Test func aSupersededTurnReportsNothing() throws {
    let out = try reports(of: [
      .message(session: "parent"), .message(session: "parent"),
      .interrupted("parent", reason: "superseded"), .succeeded("parent"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "running true", "done"])
  }

  @Test func aMessageNamingNoSessionStartsNoTurn() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .message(session: nil),
      .succeeded("parent/a"),
    ])
    #expect(
      out.map(chipSummary(of:)) == [
        "running true", "running started Explore", "running", "running ended Explore",
      ]
    )
  }

  @Test func aPermissionAskedInsideAChildIsThatWorkersPrompt() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Plan"),
      .asked("parent/a", action: "bash", resource: "echo hi"),
    ])
    #expect(
      out.map(chipSummary(of:)) == [
        "running true", "running started Plan", "attention working Plan bash echo hi",
      ]
    )
  }

  @Test func aPermissionIsReportedOnceAndItsReplyPutsTheAgentBackToWork() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .asked("parent", action: "bash", resource: "echo hi"),
      .replied("parent"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "attention bash echo hi", "running"])
  }

  /// The service's bus carries every directory's sessions, and each directory
  /// loads the plugin once, so another's would be reported twice and as ours.
  @Test func aSessionInAnotherDirectoryReportsNothing() throws {
    let out = try reports(
      of: [
        .created("elsewhere", directory: "/other"), .started("elsewhere"),
        .asked("elsewhere", action: "bash", resource: "ls"), .succeeded("elsewhere"),
        .started("unknown"), .succeeded("unknown"),
      ],
      sessions: ["unknown": ["id": "unknown", "directory": "/other"]],
    )
    #expect(out.isEmpty)
  }

  @Test func aSessionOnlyTheBusNamesIsLookedUpAndReportedWhenItIsHere() throws {
    let out = try reports(
      of: [.started("resumed"), .succeeded("resumed")],
      sessions: ["resumed": ["id": "resumed"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
  }

  @Test func everyReportNamesThePluginsDirectory() throws {
    let out = try reports(of: [.message(session: "parent"), .succeeded("parent")])
    #expect(out.map { flagValue($0, "--cwd") } == ["/w", "/w"])
  }

  /// The service keeps the environment of whichever tab started it, so its
  /// helper would name that tab, and that tab's app, for every other tab's session.
  @Test func underTheBackgroundServiceTheHelperIsToldOfNoTabAndFindsTheAppItself() throws {
    let steps: [OpenCodePluginStep] = [.message(session: "parent"), .succeeded("parent")]
    let handed = try helperEnvironments(of: steps, asService: true)
    #expect(handed == [[:], [:]])
    #expect(
      try helperEnvironments(of: steps, asService: false).isEmpty,
      "the tab's own is inherited",
    )
  }

  @Test func pastTheEndedChildLimitOnlyTheOldestLeavesTheRosterAndRejoinsAsAChild() throws {
    let steps = OpenCodePluginStep.endedChildren(
      of: "parent",
      count: OpenCodePlugin.endedChildLimit + 1,
    )
    let ended = try reports(of: steps).count
    let remembered = try reports(of: steps + [.tool(session: "parent/e1")])
    let forgotten = try reports(of: steps + [.tool(session: "parent/e0")])
    #expect(remembered.count == ended, "the second child's late call says nothing")
    #expect(
      forgotten.dropFirst(ended).map { flagValue($0, "--subagent") } == ["parent/e0", "parent/e0"],
      "the first child's call starts it again as a child, never the parent's",
    )
  }

  /// A child's id outlives its end, so a late event of its own is not read as
  /// the parent's Done.
  @Test func anEventAfterAChildHasEndedReportsNothing() throws {
    let out = try reports(of: [
      .created(child: "a", of: "parent", agent: "Explore"),
      .succeeded("parent/a"),
      .succeeded("parent/a"),
      .tool(session: "parent/a"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running started Explore", "running ended Explore"])
  }

  /// With more than one place, the cycling child would push another's id out, and that
  /// child's late event would read as the parent's Done.
  @Test func aChildRunningAndEndingOverAndOverKeepsOnePlaceAmongTheEndedIds() throws {
    var steps: [OpenCodePluginStep] = [
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .succeeded("parent/b"),
    ]
    for _ in 0...OpenCodePlugin.endedChildLimit {
      steps.append(.started("parent/a"))
      steps.append(.succeeded("parent/a"))
    }
    steps.append(.succeeded("parent/b"))

    let out = try reports(of: steps).map(chipSummary(of:))
    #expect(out.last == "running ended Explore", "b's late end says nothing")
    #expect(!out.contains("done"), "and is not read as the parent's Done")
  }

  /// A task resumed by its id reuses its session and publishes no `session.created`,
  /// so a plugin that has lost the id must ask for it.
  @Test func aResumedChildsFirstMessageStartsNoTurnOfTheParents() throws {
    let out = try reports(
      of: [.message(session: "parent"), .message(session: "parent/a"), .succeeded("parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent"]],
    )
    #expect(
      out.map(chipSummary(of:)) == [
        "running true", "running started", "running working", "running ended",
      ]
    )
  }

  @Test func aChildOfAChildNamesItsParentAndAChildOfTheSessionNamesNone() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "general"),
      .created(child: "b", of: "parent/a", agent: "explore"),
      .tool(session: "parent/a/b"),
    ])
    let workerReports = out.filter { flagValue($0, "--subagent") != nil }
    #expect(
      workerReports.map { flagValue($0, "--subagent-parent") } == [nil, "parent/a", "parent/a"]
    )
  }

  @Test func aResumedChildOfAChildNamesItsParentOnceLookedUp() throws {
    let out = try reports(
      of: [
        .message(session: "parent"),
        .created(child: "a", of: "parent", agent: "general"),
        .message(session: "parent/a/b"),
      ],
      sessions: ["parent/a/b": ["id": "parent/a/b", "parentID": "parent/a"]],
    )
    let grandchildReports = out.filter { flagValue($0, "--subagent") == "parent/a/b" }
    #expect(
      grandchildReports.map { flagValue($0, "--subagent-parent") } == ["parent/a", "parent/a"]
    )
  }

  @Test func aLookupThatFailsLeavesTheSessionTheParents() throws {
    let out = try reports(
      of: [.message(session: "parent"), .succeeded("parent")],
      sessions: ["parent": ["throws": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "done"])
  }

  @Test(arguments: [[:], ["parent": ["hangs": "true"]]])
  func theParentIsLookedUpOnceHoweverTheLookupEnds(sessions: [String: [String: String]]) throws {
    let out = try run(
      [
        .message(session: "parent"), .tool(session: "parent"), .tool(session: "parent"),
        .succeeded("parent"),
      ],
      sessions: sessions,
    )
    #expect(
      out.reports.map(chipSummary(of:)) == ["running true", "running", "done"],
      "the second collapses",
    )
    #expect(out.lookups == 1)
  }

  @Test func aChildWhoseLookupAnswersAfterTheBoundIsPutBackWhenItLands() throws {
    let out = try reports(
      of: [.message(session: "parent/a"), .answerLateLookups, .succeeded("parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "running started", "running ended"])
  }

  @Test func aChildPutBackByALookupIsNotStartedAgainByALateCreation() throws {
    let out = try reports(
      of: [
        .message(session: "parent/a"), .created(child: "a", of: "parent", agent: "Explore"),
        .succeeded("parent/a"),
      ],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running started", "running working", "running ended"])
  }

  /// Past the ended-child limit the oldest is forgotten, so its resumption by id is
  /// asked about again rather than read as the parent's turn.
  @Test func aChildTheRosterForgotIsReadAsAChildWhenResumedNotAsTheParent() throws {
    var steps: [OpenCodePluginStep] = [.message(session: "parent")]
    steps += OpenCodePluginStep.endedChildren(
      of: "parent",
      count: OpenCodePlugin.endedChildLimit + 1,
    )
    steps += [.started("parent/e0"), .succeeded("parent/e0")]
    let out = try reports(
      of: steps,
      sessions: ["parent/e0": ["id": "parent/e0", "parentID": "parent", "agent": "Explore"]],
    ).map(chipSummary(of:))
    #expect(!out.contains("done"), "the parent's turn is still running")
    #expect(out.suffix(2) == ["running working Explore", "running ended Explore"])
  }

  /// One session waiting on its lookup holds no other session's events: the
  /// parent's Done otherwise landed after the next prompt's Working.
  @Test func aLookupForAnotherSessionHoldsBackNoEventOfThisOne() throws {
    let out = try reports(
      of: [
        .message(session: "parent"), .started("unknown"), .succeeded("parent"),
        .message(session: "parent"),
      ],
      sessions: ["unknown": ["hangs": "true"]],
      bounds: .afterASecond,
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "done", "running true"])
  }

  @Test func aSessionOnlyTheBusNamesIsReportedOnceASlowLookupLands() throws {
    let out = try reports(
      of: [.started("resumed"), .answerLateLookups, .succeeded("resumed")],
      sessions: ["resumed": ["id": "resumed", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
  }

  /// A shutdown is the service going, whose pid the app's poll sees gone; an
  /// inactive run timed out without finishing.
  @Test func aShutdownReportsNothingAndARunEndedForInactivityHasFailed() throws {
    let out = try reports(of: [
      .message(session: "parent"), .interrupted("parent", reason: "shutdown"),
      .interrupted("parent", reason: "inactivity"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "error"])
  }

  /// Two sessions in one directory, the second woken by a child's end: one
  /// session's Done once swallowed the other's.
  @Test func eachSessionsDoneIsItsOwn() throws {
    let out = try reports(of: [
      .created("first", directory: "/w"), .created("second", directory: "/w"),
      .message(session: "first"), .started("second"), .succeeded("first"),
      .succeeded("second"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "running", "done", "done"])
  }

  /// OpenCode counts a plugin whose setup throws as failed; its subscription
  /// reporting on would be one nobody can stop or reload.
  @Test(arguments: [false, true])
  func aSetupThatFailsToRegisterAHookStopsReadingTheBus(throwsAtOnce: Bool) throws {
    let out = try run(
      [.created("here", directory: "/w"), .started("here"), .succeeded("here")],
      toolHookRejects: !throwsAtOnce,
      toolHookThrows: throwsAtOnce,
    )
    #expect(out.reports.isEmpty)
  }

  @Test func aFailedRunSaysWhyItFailed() throws {
    let out = try reports(of: [.message(session: "parent"), .failed("parent")])
    #expect(out.map(chipSummary(of:)) == ["running true", "error expired"])
  }

  /// A standalone tab's /new starts a second session beside the first, whose
  /// children are none of the second's.
  @Test func aSessionsDoneListsOnlyItsOwnChildrenAsOut() throws {
    let out = try reports(of: [
      .created("first", directory: "/w"), .created("second", directory: "/w"),
      .message(session: "first"), .created(child: "a", of: "first", agent: "Explore"),
      .created(child: "b", of: "first/a", agent: "Explore"),
      .message(session: "second"), .succeeded("second"), .succeeded("first"),
    ])
    let dones = out.filter { $0.count > 1 && $0[1] == "done" }
    #expect(dones.map { flagValue($0, "--out") } == ["", "first/a,first/a/b"])
  }

  @Test func aChildWhoseRunEndsBeforeItsLateAnswerEndsAsAChild() throws {
    let out = try reports(
      of: [
        .message(session: "parent"), .tool(session: "parent/a").unawaited(),
        .succeeded("parent/a"), .answerLateLookups, .succeeded("parent"),
      ],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent", "late": "true"]],
      bounds: .never,
    )
    let dones = out.filter { $0.count > 1 && $0[1] == "done" }
    #expect(dones.map { flagValue($0, "--out") } == [""], "the parent's alone, nothing out")
    #expect(out.contains { flagValue($0, "--subagent-phase") == "ended" })
  }

  @Test func aChildWhoseRunEndedBeforeAnAnswerPastTheBoundJoinsTheRosterEnded() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .message(session: "p/c"),
        .created(child: "g", of: "p/c", agent: "Explore"), .succeeded("p/c"), .answerLateLookups,
        .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    let phases = out.filter { flagValue($0, "--subagent") == "p/c" }
      .map { flagValue($0, "--subagent-phase") }
    #expect(phases == ["started", "ended"], "its end wakes the worktree and leaves nothing out")
    #expect(flagValue(try #require(out.last), "--out") == "p/c/g")
  }

  @Test func aChildWhoseLateAnswerLandsAfterItsParentsDoneJoinsTheRosterQuietly() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .message(session: "p/c"), .started("p/c"), .succeeded("p/c"),
        .started("p"), .succeeded("p"), .answerLateLookups,
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)).last == "done", "the parent's Done stands")
  }

  @Test func aGrandchildWhoseLateAnswerLandsAfterTheSessionsDoneJoinsTheRosterQuietly() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .created(child: "c", of: "p", agent: "Explore"),
        .tool(session: "p/c/g"), .succeeded("p/c/g"), .succeeded("p/c"), .started("p"),
        .succeeded("p"), .answerLateLookups,
      ],
      sessions: ["p/c/g": ["id": "p/c/g", "parentID": "p/c", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)).last == "done", "the session's Done stands")
  }

  @Test func aChildsLateAnswerLeavesItsParentsOwnPromptStanding() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .tool(session: "p/c"),
        .asked("p", action: "edit", resource: "x.swift"),
        .asked("p/c", action: "bash", resource: "ls"), .answerLateLookups,
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.contains { flagValue($0, "--message") == "edit x.swift" })
    #expect(out.contains { flagValue($0, "--subagent") == "p/c" }, "the late answer made a child")
    let afterParentAsks = out.drop { flagValue($0, "--message") != "edit x.swift" }.dropFirst()
    #expect(
      !afterParentAsks.contains { $0[1] == "running" && flagValue($0, "--subagent") == nil },
      "nothing answers the parent's prompt",
    )
  }

  @Test func aChildsLateAnswerLeavesAnotherSessionsPromptStanding() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .created("q", directory: "/w"), .message(session: "p"),
        .message(session: "q"), .tool(session: "p/c"),
        .asked("q", action: "edit", resource: "q.swift"),
        .asked("p/c", action: "bash", resource: "ls"), .answerLateLookups,
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.contains { flagValue($0, "--message") == "edit q.swift" })
    #expect(out.contains { flagValue($0, "--subagent") == "p/c" }, "the late answer made a child")
    let afterQAsks = out.drop { flagValue($0, "--message") != "edit q.swift" }.dropFirst()
    #expect(
      !afterQAsks.contains { $0[1] == "running" && flagValue($0, "--subagent") == nil },
      "nothing answers q's prompt",
    )
  }

  @Test func aPromptAChildRaisedAsItsOwnBecomesTheWorkersOnceItsLateAnswerLands() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .message(session: "p/c"),
        .asked("p/c", action: "bash", resource: "ls"), .answerLateLookups,
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    let afterAsking = out.drop { $0.count < 2 || $0[1] != "attention" }.dropFirst()
    #expect(
      afterAsking.contains { $0[1] == "running" && flagValue($0, "--subagent") == nil },
      "the agent's own prompt is answered",
    )
    #expect(
      afterAsking.last.map { $0[1] == "attention" && flagValue($0, "--subagent") == "p/c" }
        == true,
      "and raised again as the worker's",
    )
  }

  /// Under the service every session reports to the worktree, one roster for
  /// all, so one session's Done listing only its own dropped the other's.
  @Test func underTheServiceADoneListsEverySessionsChildrenAsOut() throws {
    let out = try run(
      [
        .created("first", directory: "/w"), .created("second", directory: "/w"),
        .message(session: "second"), .created(child: "a", of: "second", agent: "Explore"),
        .message(session: "first"), .succeeded("first"),
      ],
      asService: true,
    ).reports
    let done = try #require(out.last { $0.count > 1 && $0[1] == "done" })
    #expect(flagValue(done, "--out") == "second/a")
  }
}
