import Foundation
import Testing

@testable import MultishellCore

extension OpenCodePluginTests {
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

  @Test func aCreationNamingNoDirectoryLeavesTheSessionToBeAskedAbout() throws {
    let out = try reports(
      of: [.created("unplaced", directory: nil), .started("unplaced"), .succeeded("unplaced")],
      sessions: ["unplaced": ["id": "unplaced"]],
    )
    #expect(out.map(chipSummary(of:)) == ["running", "done"])
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
