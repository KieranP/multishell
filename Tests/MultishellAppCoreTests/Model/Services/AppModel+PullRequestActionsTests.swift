import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelPullRequestActionsTests {
  @Test func aBranchNobodyPushedIsPushedToOriginOnlyOnceAskedThenOpened() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    let pending = try #require(harness.model.pendingBranchPublish)
    #expect(pending.branch == "feat")
    #expect(pending.remote == "origin")
    #expect(pending.unpushedCommits == nil)
    #expect(host.calls.isEmpty, "nothing opened before the push")

    harness.model.answerBranchPublish(pending, publishes: true)
    try await waitUntil({ host.calls.contains("create feat into main") }, seconds: 10)
    #expect(host.calls == ["create feat into main"])
    let pushed = try await harness.git.run(
      ["ls-remote", "origin", "refs/heads/feat"],
      in: harness.project.path,
    )
    #expect(!pushed.isEmpty, "the branch is on the remote")
    #expect(!harness.model.isPublishing(feat))
  }

  /// SwiftUI may set a dialog's binding false, which answers No, before it
  /// runs the chosen button.
  @Test func pushStillPushesWhenTheDialogsDismissalAnsweredFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.createPullRequest(for: feat)
    let pending = try #require(harness.model.pendingBranchPublish)

    harness.model.answerBranchPublish(pending, publishes: false)
    harness.model.answerBranchPublish(pending, publishes: true)

    try await waitUntil({ host.calls.contains("create feat into main") }, seconds: 10)
    #expect(host.calls == ["create feat into main"])
  }

  @Test func aPushThatLandsOpensThePageThoughTheScanAfterItFails() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fake = try harness.modelOnFakeGit("case \"$*\" in *for-each-ref*) exit 1;; esac")
    let host = FakePullRequestHost()
    fake.remoteState.connections = ServiceConnections(
      pullRequestHosts: [.gitHub: host],
      ciProviders: [:],
    )
    let pending = PendingBranchPublish(
      worktree: feat,
      branch: "feat",
      remote: "origin",
      remoteBranch: "feat",
      unpushedCommits: nil,
    )
    fake.pendingBranchPublish = pending

    fake.answerBranchPublish(pending, publishes: true)

    try await waitUntil { !host.calls.isEmpty }
    #expect(host.calls == ["create feat into main"])
  }

  @Test func aWorktreeGoneWhileCreateAsksTheRemoteRaisesNoQuestion() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let (model, _) = try await createPullRequestWhileTheWorktreeGoes(in: harness, upstreamTip: nil)

    #expect(model.pendingBranchPublish == nil)
  }

  @Test func aWorktreeGoneWhileCreateAsksTheRemoteRaisesNoAlert() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let (model, _) = try await createPullRequestWhileTheWorktreeGoes(
      in: harness,
      upstreamTip: "abc",
      revList: "exit 1",
    )

    #expect(model.presentedError == nil)
  }

  @Test func aWorktreeGoneWhileCreateAsksTheRemoteOpensNoPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let (_, host) = try await createPullRequestWhileTheWorktreeGoes(
      in: harness,
      upstreamTip: "abc",
      revList: "echo 0",
    )

    #expect(host.calls.isEmpty)
  }

  private func createPullRequestWhileTheWorktreeGoes(
    in harness: GitHarness,
    upstreamTip: String?,
    revList: String = "exit 1",
  ) async throws -> (model: AppModel<FakeSurface>, host: FakePullRequestHost) {
    let feat = try await harness.createWorktree(onBranch: "feat")
    let gate = harness.root.appendingPathComponent("gate")
    let model = try harness.modelOnFakeGit(
      """
      case "$*" in
        *"remote -v"*) printf 'origin\\t/elsewhere (fetch)\\norigin\\t/elsewhere (push)\\n' ;;
        *ls-remote*) touch "$SCRATCH/asked"; \(harness.holdLine(until: gate)) ;;
        *rev-list*) \(revList) ;;
        *config*) exit 1 ;;
      esac
      """
    )
    let host = FakePullRequestHost()
    model.remoteState.connections = ServiceConnections(
      pullRequestHosts: [.gitHub: host],
      ciProviders: [:],
    )
    if let upstreamTip {
      model.remoteState.upstreams[feat.id] = BranchUpstream(
        remote: "origin",
        branch: "feat",
        tip: upstreamTip,
      )
    }
    let asked = harness.root.appendingPathComponent("asked")

    let create = Task { await model.createPullRequest(for: feat) }
    try await waitUntil { FileManager.default.fileExists(atPath: asked.path) }
    harness.store.replaceWorktrees(
      model.workspace.worktrees(of: harness.project.id).filter { $0.id != feat.id },
      forProject: harness.project.id,
    )
    model.forgetWorktrees([feat.id])
    try Data().write(to: gate)
    await create.value
    return (model, host)
  }

  @Test func aBranchTheRemoteAlreadyHasUnderItsNameIsSaidToHaveIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["update-ref", "-d", "refs/remotes/origin/feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    let pending = try #require(harness.model.pendingBranchPublish)
    #expect(pending.remoteHasBranch)
    #expect(pending.message.contains("already has feat"))
  }

  @Test func aBranchWhosePushesGoToAForkIsPublishedThere() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["remote", "add", "fork", "../fork.git"], in: feat.path)
    _ = try await harness.git.run(["config", "branch.feat.pushRemote", "fork"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.remote == "fork")
  }

  @Test func aBranchFollowingItsOwnNameWhosePushesGoToAForkIsPushedToTheFork() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["remote", "add", "fork", "../fork.git"], in: feat.path)
    _ = try await harness.git.run(["config", "remote.pushDefault", "fork"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "more"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.remote == "fork")
    #expect(harness.model.pendingBranchPublish?.remoteBranch == "feat")
  }

  @Test func aPushDefaultNamingNoRemoteLeavesTheBranchItsUpstream() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["config", "remote.pushDefault", "nosuch"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "more"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    let pending = try #require(harness.model.pendingBranchPublish)
    #expect(pending.remote == "origin")
    #expect(pending.unpushedCommits == 1)
    #expect(!pending.remoteHasBranch)
  }

  @Test func remotesGitCouldNotListBesideAPushRemoteAskNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fake = try harness.modelOnFakeGit(
      """
      case "$*" in
        *"remote -v"*) exit 128 ;;
        *branch.feat.pushRemote*) exit 1 ;;
        *remote.pushDefault*) echo fork ;;
        *rev-list*) echo 1 ;;
        *ls-remote*) exit 0 ;;
      esac
      """
    )
    fake.remoteState.connections = ServiceConnections(
      pullRequestHosts: [.gitHub: FakePullRequestHost()],
      ciProviders: [:],
    )
    fake.remoteState.upstreams[feat.id] = BranchUpstream(
      remote: "origin",
      branch: "feat",
      tip: "a",
    )

    await fake.createPullRequest(for: feat)

    #expect(fake.pendingBranchPublish == nil)
    #expect(fake.presentedError?.title == t("error.pull-request-not-started", "feat"))
  }

  @Test func aBranchPushedWithoutTrackingAndNothingNewOpensThePage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish == nil)
    #expect(host.calls == ["create feat into main"])
  }

  @Test func aMergedPullRequestTheBranchWentPastStillOpens() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(
      .success([.sample(number: 33, state: .merged, headBranch: "feat", headCommit: "older")])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.openPullRequest(of: feat)

    #expect(host.calls.last == "open #33")
  }

  @Test func aSecondCreateWhileTheFirstPreparesAsksNothingMore() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshBranchScan(of: harness.project)
    harness.git.runLog.setRecording(true)

    async let first: Void = harness.model.createPullRequest(for: feat)
    async let second: Void = harness.model.createPullRequest(for: feat)
    _ = await (first, second)

    let asked = harness.git.runLog.drain().finishedRuns.filter { $0.command.hasPrefix("ls-remote") }
    #expect(asked.count == 1)
  }

  @Test func answeringNoPushesNothingAndOpensNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.createPullRequest(for: feat)

    harness.model.answerBranchPublish(
      try #require(harness.model.pendingBranchPublish),
      publishes: false,
    )

    #expect(harness.model.pendingBranchPublish == nil)
    let pushed = try await harness.git.run(
      ["ls-remote", "origin", "refs/heads/feat"],
      in: harness.project.path,
    )
    #expect(pushed.isEmpty)
    #expect(host.calls.isEmpty)
  }

  @Test func aPushedBranchWithNothingUnpushedOpensThePageWithoutAsking() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish == nil)
    #expect(host.calls == ["list", "create me:feat into main"])
  }

  @Test func commitsTheRemoteLacksAreAskedAboutWithTheirCount() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshStatuses()

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.unpushedCommits == 1)
  }

  @Test func commitsPastABranchPushedWithoutTrackingAreAskedAbout() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    #expect(host.calls.isEmpty)
    #expect(harness.model.pendingBranchPublish?.unpushedCommits == 1)
  }

  @Test func aSecondWorktreesCreateLeavesTheQuestionAlreadyUp() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fix = try await harness.createWorktree(onBranch: "fix")
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.createPullRequest(for: feat)

    await harness.model.createPullRequest(for: fix)

    #expect(harness.model.pendingBranchPublish?.branch == "feat")
  }

  @Test func aRepositoryWithNoRemoteSaysSoRatherThanAsking() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    let feat = try await harness.createWorktree(onBranch: "feat")

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish == nil)
    #expect(harness.model.presentedError?.title == t("error.branch-not-pushed", "feat"))
  }

  @Test func remotesGitCouldNotListAreNotCalledNone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fake = try harness.modelOnFakeGit("case \"$*\" in *\"remote -v\"*) exit 128;; esac")
    fake.remoteState.connections = ServiceConnections(
      pullRequestHosts: [.gitHub: FakePullRequestHost()],
      ciProviders: [:],
    )

    await fake.createPullRequest(for: feat)

    #expect(fake.pendingBranchPublish == nil)
    #expect(fake.presentedError?.title == t("error.pull-request-not-started", "feat"))
  }

  @Test func commitsAStatusHasNotCountedYetAreAskedAboutFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "local"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.statuses[feat.id] = nil

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.unpushedCommits == 1)
  }

  @Test func aStatusThatCannotBeReadOpensNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fake = try harness.modelOnFakeGit("case \"$*\" in *status*) exit 128;; esac")
    let host = FakePullRequestHost()
    fake.remoteState.connections = ServiceConnections(
      pullRequestHosts: [.gitHub: host],
      ciProviders: [:],
    )
    fake.remoteState.upstreams[feat.id] = BranchUpstream(
      remote: "origin",
      branch: "feat",
      tip: "a",
    )

    await fake.createPullRequest(for: feat)

    #expect(host.calls.isEmpty, "the page would open without the commits it cannot count")
    #expect(fake.presentedError?.title == t("error.pull-request-not-started", "feat"))
  }

  @Test func aCommitTheLastStatusReadMissedIsAskedAboutFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshStatuses()
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "late"], in: feat.path)

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.unpushedCommits == 1)
  }

  @Test func aBranchTheRemoteDeletedSinceTheLastFetchIsAskedAboutFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    let tip = try await harness.tip(of: feat)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    _ = try await harness.git.run(["update-ref", "refs/remotes/origin/feat", tip], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.unpushedCommits == nil)
    #expect(harness.model.pendingBranchPublish != nil, "the remote has no branch to open against")
  }

  @Test func theMenuOpensAShownPullRequestAndOffersToCreateOneOtherwise() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.pullRequestMenuItem(for: feat) == .create(isPublishing: false))
    #expect(harness.model.pullRequestMenuItem(for: main) == nil, "the trunk has no pull request")

    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.pullRequestMenuItem(for: feat) == .open(number: 9))

    await harness.model.openPullRequest(of: feat)
    #expect(host.calls.last == "open #9")
  }

  @Test func aBranchWhosePullRequestWasClosedIsOfferedANewOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 12, state: .closed, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pullRequestMenuItem(for: feat) == .create(isPublishing: false))
  }

  @Test func theTrunkIsOfferedNoPullRequestThoughItsDefaultBranchIsUnresolved() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    var settings = harness.model.ownSettings(of: harness.project)
    settings.defaultBranch = "no-such-branch"
    harness.model.setSettings(settings, for: harness.project)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    let main = try #require(harness.worktree(onBranch: "main"))

    #expect(harness.model.pullRequestMenuItem(for: main) == nil)
  }

  @Test func noMenuItemWhereTheHostSaysTheRepositoryIsNotItsOwn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pullRequestMenuItem(for: feat) == nil)
    #expect(harness.model.integrationRepositoryFit(.gitHub, for: harness.project) == .notHosted)
  }

  @Test func thePushQuestionIsListedAndADismissAnswersNo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.presentations.map(\.kind) == [.branchPublish])
    _ = harness.model.replyToDismissPresentation()

    #expect(harness.model.pendingBranchPublish == nil)
  }

  @Test func aBranchWhoseUpstreamWasDeletedIsAskedAboutAndPushedAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    _ = try await harness.git.run(["fetch", "-q", "--prune", "origin"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: false)
    )
    await harness.model.createPullRequest(for: feat)

    #expect(harness.model.pendingBranchPublish?.remote == "origin")
    #expect(host.calls == ["list"], "nothing opened for a branch the remote no longer has")
  }

  @Test func aBranchTrackingAnotherNameIsPushedToThatName() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(
      ["push", "-q", "-u", "origin", "feat:kieran/feat"],
      in: feat.path,
    )
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshStatuses()
    await harness.model.createPullRequest(for: feat)
    let pending = try #require(harness.model.pendingBranchPublish)

    harness.model.answerBranchPublish(pending, publishes: true)
    try await waitUntil { host.calls.contains("create kieran/feat into main") }

    let local = try await harness.tip(of: feat)
    let remote = try await harness.git.run(
      ["ls-remote", "origin", "refs/heads/kieran/feat"],
      in: harness.project.path,
    )
    #expect(remote.hasPrefix(local), "the commit went to the branch it tracks")
    let stray = try await harness.git.run(
      ["ls-remote", "origin", "refs/heads/feat"],
      in: harness.project.path,
    )
    #expect(stray.isEmpty, "no new branch named after the local one")
  }

  @Test func aCheckOpensItsWebLinkAndNothingElse() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let web = URL(string: "https://github.com/me/demo/actions/runs/1/job/2")
    let local = URL(string: "file:///etc/passwd")

    harness.model.openCheck(
      PullRequestCheck(name: "a", workflow: nil, status: .passed, isRequired: false, link: web)
    )
    harness.model.openCheck(
      PullRequestCheck(name: "b", workflow: nil, status: .passed, isRequired: false, link: local)
    )

    #expect(harness.platform.openedWebPages == [web].compactMap(\.self))
  }
}
