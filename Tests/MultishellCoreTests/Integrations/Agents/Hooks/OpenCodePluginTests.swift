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

  @Test func anEnvelopeNamingTheDirectorySettlesWhoseSessionItIsWithNoLookup() throws {
    let out = try run(
      [
        .started("elsewhere").located(in: "/other"), .started("here").located(in: "/w"),
        .succeeded("here"),
      ],
      sessions: ["elsewhere": ["id": "elsewhere"], "here": ["throws": "true"]],
    )
    #expect(out.reports.map(chipSummary(of:)) == ["running", "done"])
  }

  /// An envelope may carry a location with no directory, which says nothing
  /// about whose session it is.
  @Test func anEnvelopeLocationNamingNoDirectoryIsAskedAbout() throws {
    let out = try reports(
      of: [.started("here").locatedNowhere(), .succeeded("here").locatedNowhere()],
      sessions: ["here": ["id": "here"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
  }

  /// Streamed parts name their session too, and a lookup that fails would be
  /// asked again for each one.
  @Test func anEventThePluginDoesNotReadAsksNothing() throws {
    let delta = OpenCodePluginStep.event(
      "message.part.delta",
      ["sessionID": AnyEncodable("unknown"), "delta": AnyEncodable("text")],
    )
    let out = try run([delta, delta, delta], sessions: ["unknown": ["throws": "true"]])
    #expect(out.reports.isEmpty)
    #expect(out.lookups == 0)
  }

  @Test func aLookupNamingAnotherDirectoryOutweighsAnEnvelopeNamingThisOne() throws {
    let out = try reports(
      of: [.started("moved").located(in: "/w"), .succeeded("moved").located(in: "/w")],
      sessions: ["moved": ["id": "moved", "directory": "/other"]],
    )
    #expect(out.isEmpty)
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

  @Test func aCreationNamingNoDirectoryLeavesTheSessionToBeAskedAbout() throws {
    let out = try reports(
      of: [.created("unplaced", directory: nil), .started("unplaced"), .succeeded("unplaced")],
      sessions: ["unplaced": ["id": "unplaced"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
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

  @Test func aLookupAnsweringNoDirectoryLeavesTheEnvelopeToSay() throws {
    let out = try reports(
      of: [.started("here").located(in: "/w"), .succeeded("here").located(in: "/w")],
      sessions: ["here": ["id": "here", "unplaced": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
  }

  /// A hook names only this directory's sessions, so one a lookup placed
  /// elsewhere is here once a hook names it, and asked about again once forgotten.
  @Test func aSessionAHookNamedIsAskedAboutAgainOnceForgotten() throws {
    var steps: [OpenCodePluginStep] = [.message(session: "named")]
    steps += OpenCodePluginStep.sessionsCreated(in: "/w", count: OpenCodePlugin.placementLimit + 1)
    steps.append(.started("named"))
    let out = try run(steps, sessions: ["named": ["id": "named", "directory": "/other"]])
    #expect(out.lookups == 2, "once for the hook, once after it was forgotten")
  }

  @Test func aChildWhoseAnswerNamesNoDirectoryIsStillAChildOfAParentHere() throws {
    let out = try reports(
      of: [.message(session: "parent"), .message(session: "parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent", "unplaced": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "running started", "running working"])
  }

  /// A hook can name a child before its creation, while its lookup fails.
  @Test func aChildAHookNamedBeforeItsCreationStaysAChildOnceTheRosterForgetsIt() throws {
    var steps: [OpenCodePluginStep] = [
      .message(session: "parent"), .message(session: "parent/a"),
      .created(child: "a", of: "parent", agent: "Explore"), .succeeded("parent/a"),
    ]
    steps += OpenCodePluginStep.endedChildren(
      of: "parent",
      count: OpenCodePlugin.endedChildLimit + 1,
    )
    steps += [.started("parent/a"), .succeeded("parent/a")]
    let out = try reports(of: steps, sessions: ["parent/a": ["throws": "true"]])
    #expect(!out.map(chipSummary(of:)).contains("done"))
  }

  @Test func aSessionAHookNamedStaysHereWhenALateAnswerNamesElsewhere() throws {
    let out = try reports(
      of: [.message(session: "named"), .answerLateLookups, .succeeded("named")],
      sessions: ["named": ["id": "named", "directory": "/other", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "done"])
  }

  /// After a reload the parent may be unknown here, and the answer may name no
  /// directory; the hook or the envelope places the session, and its parent makes it a child.
  @Test(arguments: [false, true])
  func aSessionWhoseAnswerNamesAParentIsAChildWhereverItWasPlaced(byEnvelope: Bool) throws {
    let steps: [OpenCodePluginStep] =
      byEnvelope
      ? [.started("parent/a").located(in: "/w"), .succeeded("parent/a").located(in: "/w")]
      : [.tool(session: "parent/a"), .succeeded("parent/a")]
    let out = try reports(
      of: steps,
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent", "unplaced": "true"]],
    )
    #expect(
      out.map(chipSummary(of:)) == ["running started", "running working", "running ended"]
    )
  }

  @Test func aFailedRunSaysWhyItFailed() throws {
    let out = try reports(of: [.message(session: "parent"), .failed("parent")])
    #expect(out.map(chipSummary(of:)) == ["running true", "error expired"])
  }

  @Test func aLateAnswerNamingAParentMakesAChildOfASessionAHookNamed() throws {
    let out = try reports(
      of: [.tool(session: "parent/a"), .answerLateLookups, .succeeded("parent/a")],
      sessions: [
        "parent/a": ["id": "parent/a", "parentID": "parent", "unplaced": "true", "late": "true"]
      ],
    )
    #expect(!out.map(chipSummary(of:)).contains("done"))
    #expect(out.last.map(chipSummary(of:)) == "running ended")
  }

  @Test func anEventDuringAHooksLookupIsTheHookedSessions() throws {
    let out = try reports(
      of: [.tool(session: "s").unawaited(), .asked("s", action: "bash", resource: "ls")],
      sessions: ["s": ["throws": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "attention bash ls"])
  }

  @Test func aSessionAHookNamedStaysHereWhenItsCreationNamesElsewhere() throws {
    let out = try reports(
      of: [
        .message(session: "named"), .created("named", directory: "/w/sub"), .succeeded("named"),
      ],
      sessions: ["named": ["id": "named"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "done"])
  }

  @Test func aCreationNamingAParentMakesAChildOfASessionAHookNamed() throws {
    let out = try reports(
      of: [
        .tool(session: "parent/a"),
        .created(child: "a", of: "parent", agent: "Explore", directory: nil),
        .succeeded("parent/a"),
      ],
      sessions: ["parent/a": ["throws": "true"]],
    )
    #expect(!out.map(chipSummary(of:)).contains("done"))
    #expect(out.last.map(chipSummary(of:)) == "running ended Explore")
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

  @Test func aSessionMovedAwayIsAnotherDirectorysAndOneMovedHereIsThisOnes() throws {
    let out = try reports(of: [
      .created("leaving", directory: "/w"), .message(session: "leaving"),
      .moved("leaving", to: "/other"), .started("leaving").located(in: "/other"),
      .succeeded("leaving").located(in: "/other"),
      .created("arriving", directory: "/other"), .moved("arriving", to: "/w"),
      .started("arriving"), .succeeded("arriving"),
    ])
    #expect(out.map(chipSummary(of:)) == ["running true", "idle", "running", "done"])
  }

  @Test func aSessionMovedAwayMidTurnLeavesItsTurnAndChildrenEndedHere() throws {
    let out = try reports(of: [
      .created("leaving", directory: "/w"), .message(session: "leaving"),
      .created(child: "a", of: "leaving", agent: "Explore"), .moved("leaving", to: "/other"),
    ])
    #expect(
      out.map(chipSummary(of:)) == [
        "running true", "running started Explore", "running ended Explore", "idle",
      ]
    )
  }

  @Test func aLateAnswerDoesNotUndoAMove() throws {
    let out = try reports(
      of: [
        .tool(session: "s"), .moved("s", to: "/other"), .answerLateLookups,
        .started("s").located(in: "/other"), .succeeded("s").located(in: "/other"),
      ],
      sessions: ["s": ["id": "s", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "idle"])
  }

  @Test func aSessionMovedAwayAfterItsDoneOrWhileAskingGoesIdleHere() throws {
    let afterDone = try reports(of: [
      .created("leaving", directory: "/w"), .message(session: "leaving"),
      .created(child: "a", of: "leaving", agent: "Explore"), .succeeded("leaving"),
      .moved("leaving", to: "/other"),
    ])
    #expect(afterDone.map(chipSummary(of:)).suffix(2) == ["running ended Explore", "idle"])
    let asking = try reports(of: [
      .created("leaving", directory: "/w"), .message(session: "leaving"),
      .asked("leaving", action: "bash", resource: "ls"), .moved("leaving", to: "/other"),
    ])
    #expect(asking.map(chipSummary(of:)).last == "idle")
  }

  @Test func aMovedSessionsChildRunningLaterReportsNothingHere() throws {
    let out = try reports(of: [
      .created("leaving", directory: "/w"), .message(session: "leaving"),
      .created(child: "a", of: "leaving", agent: "Explore"), .moved("leaving", to: "/other"),
      .started("leaving/a"), .succeeded("leaving/a"),
    ])
    #expect(out.map(chipSummary(of:)).last == "idle", "nothing after the move's own end")
  }

  @Test func aSessionMovedBackGetsItsChildrenBack() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .message(session: "p"),
        .created(child: "a", of: "p", agent: "Explore"), .moved("p", to: "/other"),
        .moved("p", to: "/w"), .started("p/a"), .succeeded("p/a"),
      ],
      sessions: ["p/a": ["id": "p/a", "parentID": "p", "agent": "Explore"]],
    )
    #expect(
      out.map(chipSummary(of:)).suffix(2) == ["running working Explore", "running ended Explore"]
    )
  }

  @Test func aSessionForgottenAmongTheLatestStillEndsHereWhenMovedAway() throws {
    var steps: [OpenCodePluginStep] = [.created("p", directory: "/w"), .message(session: "p")]
    steps += OpenCodePluginStep.sessionsCreated(in: "/w", count: OpenCodePlugin.placementLimit + 1)
    steps.append(.moved("p", to: "/other"))
    #expect(try reports(of: steps).map(chipSummary(of:)) == ["running true", "idle"])
  }

  @Test func aChildAnsweredAfterItsParentMovedAwayIsElsewheresToo() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .message(session: "p"), .started("p/a"),
        .moved("p", to: "/other"), .answerLateLookups, .succeeded("p/a"),
      ],
      sessions: ["p/a": ["id": "p/a", "parentID": "p", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "idle"])
  }

  @Test func aHookNamedChildOfAnotherDirectorysSessionStaysHere() throws {
    let out = try reports(
      of: [.started("p").located(in: "/other"), .message(session: "c"), .succeeded("c")],
      sessions: ["c": ["id": "c", "parentID": "p"]],
    )
    #expect(out.map(chipSummary(of:)).last.map { $0.hasSuffix("ended") || $0 == "done" } == true)
  }

  @Test func aSessionMovedHereBringsItsChildrenFromElsewhere() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/other"),
        .created(child: "a", of: "p", agent: "Explore", directory: "/other"),
        .moved("p", to: "/w"), .message(session: "p"), .started("p/a"), .succeeded("p/a"),
        .succeeded("p"),
      ],
      sessions: ["p/a": ["id": "p/a", "parentID": "p", "agent": "Explore"]],
    )
    #expect(out.contains { flagValue($0, "--subagent") == "p/a" })
    #expect(out.last.map(chipSummary(of:)) == "done")
  }

  @Test func aMovedChildsEventElsewhereKeepsItFiledUnderItsSession() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .message(session: "p"),
        .created(child: "c", of: "p", agent: "Explore"), .moved("p", to: "/other"),
        .started("p/c").located(in: "/other"), .moved("p", to: "/w"), .message(session: "p"),
        .started("p/c"), .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "agent": "Explore"]],
    )
    #expect(flagValue(try #require(out.last), "--out") == "p/c")
  }

  @Test func aSessionMovedHereBringsItsChildrensChildrenToo() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/other"),
        .created(child: "c", of: "p", agent: "Explore", directory: "/other"),
        .created(child: "g", of: "p/c", agent: "Explore", directory: "/other"),
        .moved("p", to: "/w"), .message(session: "p"), .started("p/c"), .started("p/c/g"),
        .succeeded("p"),
      ],
      sessions: [
        "p/c": ["id": "p/c", "parentID": "p", "agent": "Explore"],
        "p/c/g": ["id": "p/c/g", "parentID": "p/c", "agent": "Explore"],
      ],
    )
    #expect(flagValue(try #require(out.last), "--out") == "p/c,p/c/g")
  }

  @Test func aSessionMovedHereBringsAGrandchildWhoseEventComesBeforeItsParents() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/other"),
        .created(child: "c", of: "p", agent: "Explore", directory: "/other"),
        .created(child: "g", of: "p/c", agent: "Explore", directory: "/other"),
        .moved("p", to: "/w"), .message(session: "p"), .started("p/c/g"), .started("p/c"),
        .succeeded("p"),
      ],
      sessions: [
        "p/c": ["id": "p/c", "parentID": "p", "agent": "Explore", "directory": "/other"],
        "p/c/g": ["id": "p/c/g", "parentID": "p/c", "agent": "Explore", "directory": "/other"],
      ],
    )
    let done = try #require(out.last)
    #expect(Set(flagValue(done, "--out")?.split(separator: ",") ?? []) == ["p/c", "p/c/g"])
  }

  @Test func aGrandchildCreatedBeforeItsParentsLateAnswerCountsUnderTheTopLevelSession() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .tool(session: "p/c"),
        .created(child: "g", of: "p/c", agent: "Explore"), .answerLateLookups, .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "agent": "Explore", "late": "true"]],
    )
    let done = try #require(out.last)
    #expect(Set(flagValue(done, "--out")?.split(separator: ",") ?? []) == ["p/c", "p/c/g"])
  }

  @Test func aChildAHookNamedBeforeItsParentMovedAwayIsElsewheresOnceAnswered() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .message(session: "p"), .tool(session: "p/c"),
        .moved("p", to: "/other"), .answerLateLookups, .started("p/c"), .succeeded("p/c"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    let chips = out.map(chipSummary(of:))
    #expect(chips.sorted() == ["idle", "idle", "running", "running true"])
    #expect(chips.last == "idle")
  }

  @Test func aChildOnTheRosterWhosePlaceWasForgottenStillEnds() throws {
    var steps: [OpenCodePluginStep] = [
      .created("p", directory: "/w"), .message(session: "p"),
      .created(child: "a", of: "p", agent: "Explore"),
    ]
    steps += OpenCodePluginStep.sessionsCreated(in: "/w", count: OpenCodePlugin.placementLimit + 1)
    steps += [.succeeded("p/a"), .succeeded("p")]
    let out = try reports(of: steps, sessions: ["p": ["id": "p"], "p/a": ["throws": "true"]])
    #expect(out.map(chipSummary(of:)).suffix(2) == ["running ended Explore", "done"])
    #expect(flagValue(try #require(out.last), "--out") == "")
  }

  @Test func aChildAnEnvelopeFiledElsewhereComesBackWithItsMovedParent() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/other"), .started("p/c").located(in: "/other"),
        .moved("p", to: "/w"), .message(session: "p"), .started("p/c").located(in: "/w"),
        .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "agent": "Explore"]],
    )
    #expect(flagValue(try #require(out.last), "--out") == "p/c")
  }

  @Test func aSessionAnAnswerFilesElsewhereTakesItsChildrenAlong() throws {
    let out = try reports(
      of: [
        .message(session: "q"), .tool(session: "q/p"), .moved("q", to: "/other"),
        .created(child: "c", of: "q/p", agent: "Explore"), .started("q/p/c"), .answerLateLookups,
        .asked("q/p/c", action: "bash", resource: "ls"), .succeeded("q/p/c"),
      ],
      sessions: ["q/p": ["id": "q/p", "parentID": "q", "late": "true"]],
    )
    let chips = out.map(chipSummary(of:))
    #expect(!chips.contains { $0.hasPrefix("attention") })
    #expect(chips.filter { $0 == "running started Explore" }.count == 1)
  }

  @Test func aChildAnEnvelopeFilesElsewhereLeavesItsParentsRoster() throws {
    let out = try reports(
      of: [
        .started("p/c").located(in: "/w"), .message(session: "p"),
        .created(child: "g", of: "p/c", agent: "Explore"), .started("p/c/g"),
        .asked("p/c", action: "bash", resource: "ls").located(in: "/other"),
        .succeeded("p/c").located(in: "/other"), .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "unplaced": "true"]],
    )
    #expect(!out.map(chipSummary(of:)).contains("idle"), "the parent's turn is still running")
    #expect(flagValue(try #require(out.last), "--out") == "")
  }

  @Test func aChildAHookNamesAgainAfterItsParentMovedAwayStaysHere() throws {
    let out = try reports(
      of: [
        .message(session: "p"), .tool(session: "p/c"), .moved("p", to: "/other"),
        .tool(session: "p/c"), .answerLateLookups,
        .asked("p/c", action: "bash", resource: "ls"), .succeeded("p/c"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)).contains { $0.hasPrefix("attention") })
  }

  @Test(arguments: [nil, "/other"] as [String?])
  func aChildAnEnvelopeFiledElsewhereIsAskedAgainOnceItsParentMovesHere(
    laterEnvelope: String?
  ) throws {
    let later = OpenCodePluginStep.started("p/c")
    let out = try reports(
      of: [
        .created("p", directory: "/other"), .started("p/c").located(in: "/other"),
        .moved("p", to: "/w"), .message(session: "p"),
        laterEnvelope.map { later.located(in: $0) } ?? later, .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "agent": "Explore"]],
    )
    #expect(flagValue(try #require(out.last), "--out") == "p/c")
  }

  @Test func anotherDirectorysSessionMovingElsewhereLeavesItsChildHereAlone() throws {
    let out = try reports(
      of: [
        .started("p").located(in: "/other"), .message(session: "c"), .moved("p", to: "/third"),
        .asked("c", action: "bash", resource: "ls").located(in: "/w"),
      ],
      sessions: ["c": ["id": "c", "parentID": "p"]],
    )
    #expect(out.map(chipSummary(of:)).contains { $0.hasPrefix("attention") })
  }

  @Test func aSessionBackHereAfterAnEnvelopeFiledItElsewhereBringsItsChildrenBack() throws {
    let out = try reports(of: [
      .started("s").located(in: "/w"), .created(child: "c", of: "s", agent: "Explore"),
      .asked("s", action: "bash", resource: "ls").located(in: "/other"), .message(session: "s"),
      .asked("s/c", action: "bash", resource: "ls"),
    ])
    #expect(out.map(chipSummary(of:)).contains { $0.hasPrefix("attention") })
  }

  @Test func anAnswerNamingNoDirectoryLeavesALaterEnvelopeToSay() throws {
    let out = try reports(
      of: [
        .started("s").located(in: "/other"), .succeeded("s").located(in: "/other"),
        .started("s").located(in: "/w"), .succeeded("s").located(in: "/w"),
      ],
      sessions: ["s": ["id": "s", "unplaced": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
  }

  @Test func aSessionWhoseRecordWasForgottenGoesIdleWhenAnEnvelopeFilesItElsewhere() throws {
    var steps: [OpenCodePluginStep] = [.created("p", directory: "/w"), .message(session: "p")]
    steps += OpenCodePluginStep.sessionsCreated(in: "/w", count: OpenCodePlugin.placementLimit + 1)
    steps.append(.asked("p", action: "bash", resource: "ls").located(in: "/other"))
    #expect(try reports(of: steps).map(chipSummary(of:)) == ["running true", "idle"])
  }

  @Test func aForgottenSessionAnEnvelopeFilesElsewhereTakesItsChildrenAlong() throws {
    var steps: [OpenCodePluginStep] = [
      .created("p", directory: "/w"), .message(session: "p"),
      .created(child: "c", of: "p", agent: "Explore"),
    ]
    steps += OpenCodePluginStep.sessionsCreated(in: "/w", count: OpenCodePlugin.placementLimit - 1)
    steps += [
      .asked("p", action: "bash", resource: "ls").located(in: "/other"),
      .asked("p/c", action: "bash", resource: "ls"), .started("p/c"),
    ]
    #expect(!(try reports(of: steps).map(chipSummary(of:)).contains { $0.hasPrefix("attention") }))
  }

  @Test func anotherDirectorysSessionFirstSeenAfterItsChildIsHereLeavesTheChildRunning() throws {
    let out = try reports(
      of: [
        .message(session: "c"), .started("p").located(in: "/other"),
        .asked("c", action: "bash", resource: "ls").located(in: "/w"),
      ],
      sessions: ["c": ["id": "c", "parentID": "p"]],
    )
    #expect(!out.map(chipSummary(of:)).contains { $0.hasSuffix("ended") })
  }

  @Test func aSessionAHookBringsBackAsksAgainAboutAChildAnEnvelopeFiledElsewhere() throws {
    let out = try reports(
      of: [
        .started("s").located(in: "/w"),
        .asked("s", action: "bash", resource: "ls").located(in: "/other"),
        .started("s/c").located(in: "/other"), .message(session: "s"),
        .asked("s/c", action: "bash", resource: "ls"), .succeeded("s"),
      ],
      sessions: ["s/c": ["id": "s/c", "parentID": "s"]],
    )
    #expect(out.map(chipSummary(of:)).contains { $0.hasPrefix("attention") })
    #expect(flagValue(try #require(out.last), "--out") == "s/c")
  }

  @Test func aMoveHereOfASessionAlreadyHereStillAsksAgainAboutAnEnvelopeFiledChild() throws {
    let out = try reports(
      of: [
        .started("p/c").located(in: "/other"), .message(session: "p"), .moved("p", to: "/w"),
        .started("p/c"), .succeeded("p"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p"]],
    )
    #expect(flagValue(try #require(out.last), "--out") == "p/c")
  }

  @Test func aParentUnseenHereThatMovesAwayTakesItsChildAlong() throws {
    let out = try reports(of: [
      .created(child: "c", of: "p", agent: "Explore"), .started("p/c"), .moved("p", to: "/other"),
      .asked("p/c", action: "bash", resource: "ls"),
    ])
    let chips = out.map(chipSummary(of:))
    #expect(chips.contains("running ended Explore"))
    #expect(!chips.contains { $0.hasPrefix("attention") })
  }

  @Test func aChildTheRosterForgotSendsNoIdleWhenItLeavesWithAWorkerUnderIt() throws {
    var steps: [OpenCodePluginStep] = [
      .started("p/c").located(in: "/w"), .message(session: "p"), .succeeded("p/c"),
    ]
    steps += OpenCodePluginStep.endedChildren(of: "p", count: OpenCodePlugin.endedChildLimit + 1)
    steps += [
      .message(session: "p"), .created(child: "g", of: "p/c", agent: "Explore"),
      .asked("p/c", action: "bash", resource: "ls").located(in: "/other"),
    ]
    let out = try reports(
      of: steps,
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "unplaced": "true"]],
    )
    let chips = out.map(chipSummary(of:))
    #expect(chips.last == "running ended Explore", "its worker leaves with it")
    #expect(!chips.contains("idle"), "the parent's turn is still running")
  }

  @Test func aChildLeavingTakesTheGrandchildTheRosterPassedUpToItsSession() throws {
    var steps: [OpenCodePluginStep] = [
      .started("p/c").located(in: "/w"), .message(session: "p"),
      .created(child: "g", of: "p/c", agent: "Explore"), .started("p/c/g"), .succeeded("p/c"),
    ]
    steps += OpenCodePluginStep.endedChildren(of: "p", count: OpenCodePlugin.endedChildLimit + 1)
    steps += [
      .asked("p/c", action: "bash", resource: "ls").located(in: "/other"),
      .succeeded("p/c/g"), .succeeded("p"),
    ]
    let out = try reports(
      of: steps,
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "unplaced": "true"]],
    )
    #expect(flagValue(try #require(out.last), "--out") == "")
  }

  @Test(arguments: [false, true])
  func aParentUnseenHereThatMovesAwayMidTurnLeavesTheWorktreeIdle(childHasEnded: Bool) throws {
    var steps: [OpenCodePluginStep] = [
      .created(child: "c", of: "p", agent: "Explore"), .started("p/c"),
    ]
    if childHasEnded { steps.append(.succeeded("p/c")) }
    steps.append(.moved("p", to: "/other"))
    #expect(try reports(of: steps).map(chipSummary(of:)).last == "idle")
  }

  @Test func aChildTheRosterForgotSendsNoIdleLongAfterItsParentMovedAway() throws {
    var steps: [OpenCodePluginStep] = [
      .message(session: "p"), .tool(session: "p/c"), .answerLateLookups, .succeeded("p/c"),
    ]
    steps += OpenCodePluginStep.endedChildren(of: "p", count: OpenCodePlugin.endedChildLimit + 1)
    steps += [.succeeded("p"), .moved("p", to: "/other"), .message(session: "q")]
    steps += OpenCodePluginStep.sessionsCreated(
      in: "/other",
      count: OpenCodePlugin.placementLimit + 1,
    )
    steps.append(.asked("p/c", action: "bash", resource: "ls").located(in: "/other"))
    let out = try reports(
      of: steps,
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)).last == "running true")
  }

  @Test func aChildThatOnceReportedAsItsOwnSendsNoIdleLongAfterItsParentMovedAway() throws {
    var steps: [OpenCodePluginStep] = [
      .message(session: "p"), .tool(session: "p/c"), .answerLateLookups,
      .moved("p", to: "/other"), .message(session: "q"),
    ]
    steps += OpenCodePluginStep.sessionsCreated(
      in: "/other",
      count: OpenCodePlugin.placementLimit + 1,
    )
    steps.append(.asked("p/c", action: "bash", resource: "ls").located(in: "/other"))
    let out = try reports(
      of: steps,
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)).last == "running true")
  }

  @Test func aGrandchildAnsweredAfterItsSessionMovedAwayIsElsewheresToo() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .message(session: "p"), .started("p/c"),
        .started("p/c/g"), .moved("p", to: "/other"), .answerLateLookups,
        .asked("p/c/g", action: "bash", resource: "ls"), .succeeded("p/c/g"),
      ],
      sessions: [
        "p/c": ["id": "p/c", "parentID": "p", "late": "true"],
        "p/c/g": ["id": "p/c/g", "parentID": "p/c", "late": "true"],
      ],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "idle"])
  }

  @Test func aHookThatFiredBeforeItsParentMovedAwayKeepsNoChildHere() throws {
    let out = try reports(
      of: [
        .created("p", directory: "/w"), .message(session: "p"), .started("p/c"),
        .tool(session: "p/c"), .moved("p", to: "/other"), .answerLateLookups,
        .asked("p/c", action: "bash", resource: "ls"), .succeeded("p/c"),
      ],
      sessions: ["p/c": ["id": "p/c", "parentID": "p", "late": "true"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running true", "idle"])
  }

  @Test func aGrandchildUnderAnUnknownParentLeavesWithItsMovedSession() throws {
    let out = try reports(
      of: [
        .created(child: "g", of: "t/k", agent: "Explore"), .started("t/k/g"),
        .moved("t", to: "/other"), .asked("t/k/g", action: "bash", resource: "ls"),
      ],
      sessions: ["t/k": ["id": "t/k", "parentID": "t"], "t": ["id": "t"]],
    )
    let chips = out.map(chipSummary(of:))
    #expect(chips.last == "idle")
    #expect(!chips.contains { $0.hasPrefix("attention") })
  }

  @Test func aMoveAwayForgetsNoOtherSessionsEndedChild() throws {
    var steps: [OpenCodePluginStep] = [.message(session: "q")]
    steps += OpenCodePluginStep.endedChildren(of: "q", count: OpenCodePlugin.endedChildLimit)
    steps += [
      .message(session: "p"), .created(child: "r", of: "p", agent: "Explore"),
      .moved("p", to: "/other"), .succeeded("q/e0"),
    ]
    #expect(
      try reports(of: steps).map(chipSummary(of:)).last == "idle",
      "q/e0's stray end says nothing",
    )
  }

  @Test func aGrandchildStillRunningCountsUnderTheSessionOnceItsEndedParentIsForgotten() throws {
    var steps: [OpenCodePluginStep] = [
      .message(session: "p"), .created(child: "c", of: "p", agent: "Explore"),
      .created(child: "g", of: "p/c", agent: "Explore"), .succeeded("p/c"),
    ]
    steps += OpenCodePluginStep.endedChildren(of: "p", count: OpenCodePlugin.endedChildLimit + 1)
    steps.append(.succeeded("p"))
    let done = try #require(try reports(of: steps).last)
    #expect(flagValue(done, "--out") == "p/c/g")
  }

  @Test func aSessionAHookNamedKeepsItsPlaceWhileOtherDirectoriesSessionsComeAndGo() throws {
    var steps: [OpenCodePluginStep] = [.message(session: "named")]
    steps += OpenCodePluginStep.sessionsCreated(
      in: "/other",
      count: OpenCodePlugin.placementLimit + 1,
    )
    steps.append(.succeeded("named"))
    let out = try reports(of: steps, sessions: ["named": ["id": "named", "directory": "/w/sub"]])
    #expect(out.map(chipSummary(of:)) == ["running true", "done"])
  }
}
