import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelConflictHandoffTests {
  @Test func sendConflictsPastesAMentionOfTheFileListingThemAndLeavesReturnToTheUser() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let session = try harness.openAgentTab(in: feature, working: false)
    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    await harness.model.sendConflicts(of: feature, to: session.id)

    let pasted = try #require(harness.engine.pasted.last)
    #expect(pasted.id == session.id)
    #expect(pasted.text.hasPrefix("@"))
    #expect(pasted.text.contains("conflicts-feature.md"))
    #expect(!pasted.text.contains("\r") && !pasted.text.contains("\n"))
    let file = try harness.conflictsFile()
    #expect(file.contains("A merge in this worktree stopped on conflicts"))
    #expect(file.contains("env GIT_EDITOR=true git merge --continue"))
    #expect(file.contains("\n    README.md\n"))
  }

  @Test func sendConflictsAfterTheyWereResolvedRereadsTheRowAndSendsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let session = try harness.openAgentTab(in: feature, working: false)
    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    _ = try await harness.git.run(["add", "README.md"], in: feature.path)
    let pastedBefore = harness.engine.pasted.count

    await harness.model.sendConflicts(of: feature, to: session.id)

    #expect(harness.engine.pasted.count == pastedBefore)
    #expect(harness.model.statuses[feature.id]?.conflicted == 0)
  }

  @Test func withTheSettingOnAConflictOpensANewAgentTabOnItsOwnPrompt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent(AgentCatalogue.claudeID)
    harness.model.setSendsConflictsToPreferredAgent(true)
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let existing = try harness.openAgentTab(in: feature, working: true)
    let pastedBefore = harness.engine.pasted.count

    let run = await harness.model.runBaseUpdate(
      feature,
      by: .rebase,
      onto: try #require(harness.model.updatableBase(of: feature)),
      consenting: BaseUpdateConsent(overWorkingAgent: true),
    ).run

    let pane = try #require(run?.conflictPane)
    #expect(pane != existing.id)
    #expect(run?.outcome == .unfinished(conflictedPaths: ["README.md"]))
    let launched = try #require(harness.engine.opened.last { $0.id == pane })
    let line = try #require(launched.command?.last)
    #expect(line.contains("Resolve the conflicts listed in @"))
    #expect(
      line.contains("conflicts-feature.md, then run env GIT_EDITOR=true git rebase --continue.")
    )
    #expect(harness.engine.pasted.count == pastedBefore, "the working agent is left alone")
    #expect(try harness.conflictsFile().contains("env GIT_EDITOR=true git rebase --continue"))
  }

  @Test func withTheSettingOnARebaseCancelledWhileGitRanStillOpensTheTab() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent(AgentCatalogue.claudeID)
    harness.model.setSendsConflictsToPreferredAgent(true)
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let base = try #require(harness.model.updatableBase(of: feature))
    let gate = harness.root.appendingPathComponent("gate")
    let rebasing = harness.root.appendingPathComponent("rebasing")
    try harness.wrapGit(
      in: """
        if [ "$1" = rebase ]; then
          touch '\(rebasing.path)'
          \(harness.holdLine(until: gate))
        fi
        """
    )

    let update = Task {
      await harness.model.runBaseUpdate(feature, by: .rebase, onto: base, consenting: .init())
    }
    try await waitUntil({ FileManager.default.fileExists(atPath: rebasing.path) }, seconds: 10)
    update.cancel()
    try Data().write(to: gate)
    let run = await update.value.run

    #expect(run?.outcome == .unfinished(conflictedPaths: ["README.md"]))
    #expect(run?.conflictPane != nil)
  }

  @Test func withTheSettingOnButNoAgentChosenConflictsWait() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSendsConflictsToPreferredAgent(true)
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let opened = harness.engine.opened.count

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)

    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .rebase)
    #expect(harness.engine.opened.count == opened)
    #expect(harness.model.presentedError == nil)
  }

  @Test func aProjectOverrideTurnsTheSendOnForItsWorktreesAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent(AgentCatalogue.claudeID)
    var settings = harness.project.settings
    settings.sendsConflictsToPreferredAgent = true
    harness.store.setSettings(settings, forProject: harness.project.id)
    let feature = try await harness.featureBehindOrigin(conflicting: true)

    let run = await harness.model.runBaseUpdate(
      feature,
      by: .merge,
      onto: try #require(harness.model.updatableBase(of: feature)),
      consenting: BaseUpdateConsent(),
    ).run

    #expect(!harness.model.workspace.sendsConflictsToPreferredAgent)
    #expect(run?.conflictPane != nil)
  }

  @Test func aMergeAHookRejectedShowsGitsWordsAndHasNoConflictsToSend() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent(AgentCatalogue.claudeID)
    let feature = try await harness.featureBehindOrigin()
    let hook = harness.project.path.appendingPathComponent(".git/hooks/commit-msg")
    try Scratch.script("echo 'no ticket in the message' >&2\nexit 1", at: hook)
    let opened = harness.engine.opened.count

    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    await harness.model.sendConflictsToNewAgentTab(of: feature)

    #expect(harness.model.presentedError?.message.contains("no ticket in the message") == true)
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .merge)
    #expect(harness.engine.opened.count == opened, "no agent is told to resolve nothing")
    #expect(
      harness.model.baseUpdateMenu(for: feature)
        == .unfinished(.merge, sendTargets: nil, isRunning: false)
    )
  }

  @Test func conflictsSentMidRebaseAreFiledUnderTheBranchNotTheShortCommit() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setPreferredAgent(AgentCatalogue.claudeID)
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    let detached = try #require(harness.model.workspace.worktree(feature.id))
    #expect(detached.branch == nil)

    await harness.model.sendConflictsToNewAgentTab(of: detached)

    let line = try #require(harness.engine.opened.last?.command?.last)
    #expect(line.contains("conflicts-feature.md"))
  }
}
