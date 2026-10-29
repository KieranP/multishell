import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelPullRequestMergeTests {
  private static let options = PullRequestMergeOptions(
    methods: [.merge, .squash],
    defaultMethod: .squash,
    messages: [
      .merge: PullRequestMergeMessage(subject: "Merge pull request #44 from me/feat", body: "T"),
      .squash: PullRequestMergeMessage(subject: "T (#44)", body: "* one\n\n* two"),
    ],
    allowsAutoMerge: true,
    viewerMayMerge: true,
  )

  private static func checks(_ status: CIRunStatus) -> PullRequestChecks {
    PullRequestChecks(
      pullRequestNumber: 44,
      headCommit: "tip",
      checks: [
        PullRequestCheck(name: "test", workflow: "CI", status: status, isRequired: true, link: nil)
      ],
    )
  }

  private static func worktree(
    showing pullRequest: PullRequest,
    in harness: GitHarness,
  ) async throws -> (FakePullRequestHost, Worktree) {
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([pullRequest]))
    host.answerMergeOptions(.success(options))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.checks[feat.id] = checks(.passed)
    return (host, feat)
  }

  private static func holdAPollRead(
    of host: FakePullRequestHost,
    in harness: GitHarness,
  ) async throws -> Task<Void, Never> {
    let lists = host.calls.filter { $0 == "list" }.count
    host.holdList()
    let poll = Task { await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls.filter { $0 == "list" }.count > lists }
    return poll
  }

  @Test func mergeOpensTheFormOnGitHubsDefaultMethodAndItsMessage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, feat) = try await Self.worktree(showing: .sample(), in: harness)

    await harness.model.beginMerge(of: feat)

    let pending = try #require(harness.model.pendingMerge(of: feat))
    #expect(pending.method == .squash)
    #expect(pending.message == Self.options.messages[.squash])
    #expect(!pending.waitsForChecks)
    #expect(pending.confirmTitle == "Squash and Merge")
  }

  @Test func confirmingSendsTheEditedMessageHeldToThePagesHeadThenListsAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(),
      in: harness,
    )
    await harness.model.beginMerge(of: feat)
    harness.model.setMergeSubject("Edited", for: feat)
    let listsBefore = host.calls.filter { $0 == "list" }.count

    await harness.model.confirmMerge(of: feat)

    #expect(host.calls.contains("merge #44 squash at tip Edited|* one\n\n* two"))
    #expect(harness.model.pendingMerge(of: feat) == nil, "the list read after it ends the form")
    #expect(host.calls.filter { $0 == "list" }.count == listsBefore + 1)
  }

  @Test func aSentAutoMergeFormEndsAtAListReadBegunAfterItThoughAutoMergeIsOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    defer { host.releaseHeldReads() }
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)
    await harness.model.beginMerge(of: feat)
    let poll = try await Self.holdAPollRead(of: host, in: harness)

    await harness.model.confirmMerge(of: feat)
    let sent = try #require(harness.model.pendingMerge(of: feat))
    #expect(sent.wasAccepted)
    #expect(sent.confirmTitle == nil, "nothing to merge again")
    host.releaseHeldReads()
    await poll.value

    try await waitUntil { harness.model.pendingMerge(of: feat) == nil }
    #expect(harness.model.pendingMerge(of: feat) == nil)
  }

  @Test func aMergeTheHostRefusesKeepsTheFormAndSaysWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(),
      in: harness,
    )
    host.failMerges(saying: "Head branch was modified")
    await harness.model.beginMerge(of: feat)

    await harness.model.confirmMerge(of: feat)

    let pending = try #require(harness.model.pendingMerge(of: feat))
    #expect(pending.phase == .editing)
    #expect(harness.model.presentedError?.title == "#44 was not merged")
    #expect(harness.model.presentedError?.message.contains("Head branch was modified") == true)
  }

  @Test func aSecondConfirmWhileTheFirstRunsSendsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(),
      in: harness,
    )
    defer { host.releaseHeldWrites() }
    host.holdMerges()
    await harness.model.beginMerge(of: feat)
    let first = Task { await harness.model.confirmMerge(of: feat) }
    try await waitUntil { harness.model.pendingMerge(of: feat)?.phase == .sending }

    await harness.model.confirmMerge(of: feat)
    harness.model.dismissMergeForm(of: feat)
    #expect(harness.model.pendingMerge(of: feat) != nil, "a merge sent is not called back")
    host.releaseHeldWrites()
    await first.value

    #expect(host.calls.filter { $0.hasPrefix("merge #") }.count == 1)
  }

  @Test func checksStillRunningTurnAutoMergeOnInstead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)
    await harness.model.beginMerge(of: feat)
    let pending = try #require(harness.model.pendingMerge(of: feat))
    #expect(pending.waitsForChecks)
    #expect(pending.confirmTitle == "Enable Auto-Merge")

    await harness.model.confirmMerge(of: feat)

    #expect(
      host.calls.contains { $0.hasPrefix("merge #44 squash at tip") && $0.hasSuffix(" auto") }
    )
  }

  @Test func checksPassingWhileTheFormIsOpenMergeAtOnceInstead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)
    await harness.model.beginMerge(of: feat)

    harness.model.setFilesPanelMode(.pullRequest)
    host.answerChecks(Self.checks(.passed).checks ?? [])

    await harness.model.readPanelServicesIfDue(of: feat)
    await harness.model.confirmMerge(of: feat)

    #expect(host.calls.contains("merge #44 squash at tip T (#44)|* one\n\n* two"))
  }

  @Test func checksPassedBehindGitHubsUnknownStillWaitAsTheBannerWould() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)
    await harness.model.beginMerge(of: feat)

    harness.model.remoteState.checks[feat.id] = Self.checks(.passed)
    host.answer(.success([.sample(hasConflictAnswer: false)]))
    await harness.model.refreshServices(ofProject: harness.project.id)

    let shown = try #require(harness.model.services(of: feat).shownPullRequest)
    let readiness = harness.model.mergeReadiness(of: shown, in: feat)
    #expect(harness.model.pendingMerge(of: feat)?.waitsForChecks == true)
    #expect(harness.model.mergeAction(for: readiness, in: feat) == .mergeWhenReady)
  }

  @Test func aCheckFailingDropsTheForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, feat) = try await Self.worktree(showing: .sample(), in: harness)
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)
    await harness.model.beginMerge(of: feat)

    harness.model.remoteState.checks[feat.id] = Self.checks(.failed)
    harness.model.reconcileMerges(of: [feat.id])

    #expect(harness.model.pendingMerge(of: feat) == nil)
  }

  @Test func gitHubWorkingOutConflictsAfterTheBaseMovedLeavesTheFormOpen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    host.answer(.success([.sample(hasConflictAnswer: false)]))
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pendingMerge(of: feat) != nil)
  }

  @Test func aSentAutoMergeFormEndsOnceTheListShowsAutoMergeOn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    defer { host.releaseHeldReads() }
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)
    await harness.model.beginMerge(of: feat)
    let poll = try await Self.holdAPollRead(of: host, in: harness)
    await harness.model.confirmMerge(of: feat)
    host.answer(.success([.sample(autoMergesWhenReady: true)]))

    host.releaseHeldReads()
    await poll.value

    #expect(harness.model.pendingMerge(of: feat) == nil, "dropped by the read begun before it")
  }

  @Test func doneBeforeTheListAnswersOffersNoMergeUntilItDoes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    defer { host.releaseHeldReads() }
    await harness.model.beginMerge(of: feat)
    let poll = try await Self.holdAPollRead(of: host, in: harness)
    await harness.model.confirmMerge(of: feat)
    let shown = try #require(harness.model.services(of: feat).shownPullRequest)

    harness.model.dismissMergeForm(of: feat)

    #expect(harness.model.pendingMerge(of: feat) == nil)
    #expect(
      harness.model.mergeAction(for: harness.model.mergeReadiness(of: shown, in: feat), in: feat)
        == nil,
      "the list predates the merge",
    )
    host.releaseHeldReads()
    await poll.value
    try await waitUntil { harness.model.remoteState.pendingMerges[feat.id] == nil }
    #expect(
      harness.model.mergeAction(for: harness.model.mergeReadiness(of: shown, in: feat), in: feat)
        == .merge,
      "the list answered since",
    )
  }

  @Test func aReadBegunByAnEarlierOpeningDoesNotFillALaterOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(),
      in: harness,
    )
    host.holdMergeOptions()
    let first = Task { await harness.model.beginMerge(of: feat) }
    try await waitUntil { host.calls.contains("merge options #44") }
    harness.model.dismissMergeForm(of: feat)
    let later = PullRequestMergeOptions(
      methods: [.rebase],
      defaultMethod: .rebase,
      messages: [:],
      allowsAutoMerge: true,
      viewerMayMerge: true,
    )
    host.answerMergeOptions(.success(later))
    let second = Task { await harness.model.beginMerge(of: feat) }
    try await waitUntil { host.calls.filter { $0 == "merge options #44" }.count == 2 }

    host.releaseMergeOptionsRead(1)
    await second.value
    host.releaseMergeOptionsRead(0)
    await first.value

    #expect(harness.model.pendingMerge(of: feat)?.options == later)
  }

  @Test func aRepositoryWithAutoMergeOffRefusesMergeWhenReadyInTheForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    host.answerMergeOptions(
      .success(
        PullRequestMergeOptions(
          methods: [.squash],
          defaultMethod: .squash,
          messages: Self.options.messages,
          allowsAutoMerge: false,
          viewerMayMerge: true,
        )
      )
    )
    harness.model.remoteState.checks[feat.id] = Self.checks(.running)

    await harness.model.beginMerge(of: feat)

    let pending = try #require(harness.model.pendingMerge(of: feat))
    #expect(!pending.canConfirm)
    #expect(pending.statusNote(hostName: "GitHub")?.contains("Auto-merge") == true)
  }

  @Test func anAccountThatMayNotMergeCannotConfirm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    host.answerMergeOptions(
      .success(
        PullRequestMergeOptions(
          methods: [.squash],
          defaultMethod: .squash,
          messages: Self.options.messages,
          allowsAutoMerge: true,
          viewerMayMerge: false,
        )
      )
    )

    await harness.model.beginMerge(of: feat)

    let pending = try #require(harness.model.pendingMerge(of: feat))
    #expect(!pending.canConfirm)
    #expect(pending.statusNote(hostName: "GitHub") != nil)
  }

  @Test func aPushSeenWhileTheFormIsOpenTurnsBackToThePage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    host.answer(.success([.sample(headCommit: "pushed")]))
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pendingMerge(of: feat) == nil)
  }

  @Test func anotherRepositorysPullRequestOfTheSameNumberAndHeadDropsTheForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    host.answer(.success([.sample(baseRepository: "upstream/demo")]))
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pendingMerge(of: feat) == nil)
  }

  @Test func turningTheHostOffDropsTheForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)

    #expect(harness.model.remoteState.pendingMerges[feat.id] == nil)
  }

  @Test func aCheckoutForgettingTheRowsServicesKeepsACancelInFlight() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(autoMergesWhenReady: true),
      in: harness,
    )
    defer { host.releaseHeldWrites() }
    host.holdMerges()
    let cancel = Task { await harness.model.cancelAutoMerge(of: feat) }
    try await waitUntil { host.calls.contains("disable auto-merge #44") }

    harness.model.forgetBranchServices(of: [feat.id])

    #expect(harness.model.remoteState.autoMergeCancellations[feat.id] != nil)
    host.releaseHeldWrites()
    await cancel.value
  }

  @Test func aCancelInFlightHoldsOnlyItsOwnPullRequestsButton() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(autoMergesWhenReady: true),
      in: harness,
    )
    defer { host.releaseHeldWrites() }
    host.holdMerges()
    let cancel = Task { await harness.model.cancelAutoMerge(of: feat) }
    try await waitUntil { host.calls.contains("disable auto-merge #44") }

    host.answer(.success([.sample(number: 45)]))
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(!harness.model.isCancellingAutoMerge(of: feat), "#45 is not the one cancelled")
    #expect(harness.model.remoteState.autoMergeCancellations[feat.id] != nil, "#44's still runs")
    host.releaseHeldWrites()
    await cancel.value
  }

  @Test func anAcceptedMergeKeepsTheBannersHoldAcrossACheckout() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    defer { host.releaseHeldReads() }
    await harness.model.beginMerge(of: feat)
    let poll = try await Self.holdAPollRead(of: host, in: harness)
    await harness.model.confirmMerge(of: feat)
    harness.model.dismissMergeForm(of: feat)

    harness.model.forgetBranchServices(of: [feat.id])
    await harness.model.refreshBranchScan(of: harness.project)

    let shown = try #require(harness.model.services(of: feat).shownPullRequest)
    let readiness = harness.model.mergeReadiness(of: shown, in: feat)
    #expect(harness.model.mergeAction(for: readiness, in: feat) == nil, "GitHub already took it")
    host.releaseHeldReads()
    await poll.value
  }

  @Test func turningTheHostOffEndsACancelInFlight() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(autoMergesWhenReady: true),
      in: harness,
    )
    defer { host.releaseHeldWrites() }
    host.holdMerges()
    let cancel = Task { await harness.model.cancelAutoMerge(of: feat) }
    try await waitUntil { host.calls.contains("disable auto-merge #44") }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)

    #expect(!harness.model.isCancellingAutoMerge(of: feat))
    host.releaseHeldWrites()
    await cancel.value
  }

  @Test func cancellingAutoMergeAsksTheHostToTurnItOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(autoMergesWhenReady: true),
      in: harness,
    )

    await harness.model.cancelAutoMerge(of: feat)

    #expect(host.calls.contains("disable auto-merge #44"))
  }

  @Test func aSecondCancelWhileTheFirstRunsAsksNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(autoMergesWhenReady: true),
      in: harness,
    )
    defer { host.releaseHeldWrites() }
    host.holdMerges()
    let first = Task { await harness.model.cancelAutoMerge(of: feat) }
    try await waitUntil { host.calls.contains("disable auto-merge #44") }
    #expect(harness.model.isCancellingAutoMerge(of: feat))

    await harness.model.cancelAutoMerge(of: feat)
    host.releaseHeldWrites()
    await first.value

    #expect(host.calls.filter { $0 == "disable auto-merge #44" }.count == 1)
  }

  @Test func cancelAutoMergeStaysOffUntilAListReadBegunAfterItAnswers() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(autoMergesWhenReady: true),
      in: harness,
    )
    defer { host.releaseHeldReads() }
    let poll = try await Self.holdAPollRead(of: host, in: harness)

    await harness.model.cancelAutoMerge(of: feat)
    #expect(harness.model.isCancellingAutoMerge(of: feat), "the read in flight began before it")
    #expect(harness.model.isMergeActionBusy(.cancelAutoMerge, of: feat))
    #expect(!harness.model.isMergeActionBusy(.merge, of: feat), "only its own action")
    host.releaseHeldReads()
    await poll.value

    try await waitUntil { !harness.model.isCancellingAutoMerge(of: feat) }
    #expect(!harness.model.isCancellingAutoMerge(of: feat), "though the list says it is on again")
  }

  @Test func eachMethodKeepsItsOwnEditsAndRestoreGoesBackToGitHubs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    harness.model.setMergeBody("Squashed", for: feat)
    harness.model.chooseMergeMethod(.merge, for: feat)
    #expect(harness.model.pendingMerge(of: feat)?.message == Self.options.messages[.merge])
    harness.model.chooseMergeMethod(.squash, for: feat)
    #expect(harness.model.pendingMerge(of: feat)?.message?.body == "Squashed")
    #expect(harness.model.pendingMerge(of: feat)?.isEdited == true)

    harness.model.restoreMergeMessage(for: feat)

    #expect(harness.model.pendingMerge(of: feat)?.message == Self.options.messages[.squash])
    #expect(harness.model.pendingMerge(of: feat)?.isEdited == false)
  }

  @Test func aMethodTheRepositoryDisallowsCannotBeChosen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    harness.model.chooseMergeMethod(.rebase, for: feat)

    #expect(harness.model.pendingMerge(of: feat)?.method == .squash)
  }

  @Test func anEmptySubjectCannotBeConfirmed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, feat) = try await Self.worktree(showing: .sample(), in: harness)
    await harness.model.beginMerge(of: feat)

    harness.model.setMergeSubject("  ", for: feat)

    #expect(harness.model.pendingMerge(of: feat)?.canConfirm == false)
  }

  @Test func aConflictingPullRequestOpensNoForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(blocker: .conflicts), in: harness)

    await harness.model.beginMerge(of: feat)

    #expect(harness.model.pendingMerge(of: feat) == nil)
    #expect(!host.calls.contains("merge options #44"))
  }

  @Test func optionsTheHostCouldNotReadAreSaidInTheForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    host.answerMergeOptions(.failure(.failed("GraphQL: Could not resolve to a Repository")))

    await harness.model.beginMerge(of: feat)

    #expect(harness.model.pendingMerge(of: feat)?.canConfirm == false)
    #expect(
      harness.model.mergeReadProblem(of: feat) == "GraphQL: Could not resolve to a Repository"
    )
  }

  @Test func aPullRequestMergedElsewhereWhileTheFormIsOpenShowsThePageAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(
      showing: .sample(),
      in: harness,
    )
    await harness.model.beginMerge(of: feat)

    host.answer(.success([.sample(state: .merged)]))
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pendingMerge(of: feat) == nil)
  }

  @Test func aWorktreeRemovedMidMergeTakesItsFormWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, feat) = try await Self.worktree(showing: .sample(), in: harness)
    defer { host.releaseHeldWrites() }
    host.holdMerges()
    await harness.model.beginMerge(of: feat)
    let merge = Task { await harness.model.confirmMerge(of: feat) }
    try await waitUntil { harness.model.pendingMerge(of: feat)?.isSending == true }

    try await harness.removeOutsideTheApp(feat.path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.model.remoteState.pendingMerges[feat.id] == nil)
    host.releaseHeldWrites()
    await merge.value
    #expect(
      harness.model.remoteState.pendingMerges[feat.id] == nil,
      "the merge's answer adds none",
    )
  }
}
