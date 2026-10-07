import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelWorktreeRemovalRequestTests {
  @Test func askingToRemoveAWorktreeReadsItsStatusFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side", basedOn: nil, createsBranch: true, in: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    try harness.dirty(side)
    harness.clearStatuses()

    harness.model.requestWorktreeRemoval(of: side)

    try await waitUntil { harness.model.pendingWorktreeRemoval != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRemovalThatAsksNothingRequestedTwiceRunsOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side", basedOn: nil, createsBranch: true, in: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let log = harness.root.appendingPathComponent("pre-delete.log")
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: "echo ran >> \(log.path)"), for: harness.project)
    harness.model.setConfirmsWorktreeRemoval(false)
    harness.model.setDeletesBranchWithWorktree(true)

    harness.model.requestWorktreeRemoval(of: side)
    harness.model.requestWorktreeRemoval(of: side)

    try await waitUntil { harness.worktree(onBranch: "side") == nil }
    await harness.awaitOperationEnd(on: side.id)
    let runs = try String(contentsOf: log, encoding: .utf8)
    #expect(runs == "ran\n")
  }

  @Test func aSlowWorktreeIsStillReadBeforeItsRemovalDialog() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side", basedOn: nil, createsBranch: true, in: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    try harness.dirty(side)
    harness.clearStatuses()
    harness.model.statusReadLog.pace = .standard
    harness.model.statusReadLog.remember([side.id: .seconds(10)])

    harness.model.requestWorktreeRemoval(of: side)

    try await waitUntil { harness.model.pendingWorktreeRemoval != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRowOnScreenThePaceHoldsBackIsStillReadBeforeItsRemovalDialog() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side", basedOn: nil, createsBranch: true, in: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    try harness.dirty(side)
    harness.clearStatuses()
    harness.model.statusReadLog.pace = .standard
    harness.model.statusReadLog.remember([side.id: .seconds(3)])

    await harness.model.requestWorktreeRemoval(of: side)?.value

    #expect(harness.model.pendingWorktreeRemoval != nil)
    #expect(harness.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRemovalReadLandingLateLeavesTheDialogThatOpenedMeanwhile() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "gated", basedOn: nil, createsBranch: true, in: harness.project)
    await harness.model.createWorktree(
      branch: "quick", basedOn: nil, createsBranch: true, in: harness.project)
    let gated = try #require(harness.worktree(onBranch: "gated"))
    let quick = try #require(harness.worktree(onBranch: "quick"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let gate = harness.root.appendingPathComponent("go")
    let fake = try harness.modelOnFakeGit(
      """
      case "$PWD $*" in
        *gated*status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done; printf '## gated\\n' ;;
        *quick*status*) printf '## quick\\n' ;;
      esac
      """)

    fake.requestWorktreeRemoval(of: gated)
    try await waitUntil { harness.statusRunCount() > 0 }
    fake.requestWorktreeRemoval(of: quick)
    try await waitUntil { fake.pendingWorktreeRemoval != nil }
    #expect(fake.pendingWorktreeRemoval?.worktree.id == quick.id)
    try Data().write(to: gate)
    try await waitUntil { fake.statuses[gated.id] != nil }
    #expect(fake.statuses[gated.id] != nil, "the late read landed")

    #expect(
      fake.pendingWorktreeRemoval?.worktree.id == quick.id, "the dialog up is the one confirmed")
  }

  @Test func aRemovalAskedTwiceWhileItsStatusIsReadReadsItOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "gated", basedOn: nil, createsBranch: true, in: harness.project)
    let gated = try #require(harness.worktree(onBranch: "gated"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let gate = harness.root.appendingPathComponent("go")
    let fake = try harness.modelWithStatusHeld(until: gate, answering: "gated")

    fake.requestWorktreeRemoval(of: gated)
    fake.requestWorktreeRemoval(of: gated)
    try await waitUntil { harness.statusRunCount() > 0 }
    try Data().write(to: gate)
    try await waitUntil { fake.pendingWorktreeRemoval != nil }

    #expect(harness.statusRunCount() == 1)
  }

  @Test func aRemovalWhoseStatusReadHangsStillOpensItsDialog() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "hung", basedOn: nil, createsBranch: true, in: harness.project)
    let hung = try #require(harness.worktree(onBranch: "hung"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let gate = harness.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let fake = try harness.modelWithStatusHeld(until: gate, answering: "hung")
    fake.removalStatusWait = .milliseconds(100)

    fake.requestWorktreeRemoval(of: hung)

    try await waitUntil { fake.pendingWorktreeRemoval != nil }
    let pending = try #require(fake.pendingWorktreeRemoval)
    let warning = fake.worktreeRemovalWarning(for: pending)
    #expect(pending.message(warning: warning).contains("could not be read"))
  }

  @Test func askingAgainWhileTheLastRemovalsReadStillHangsStartsNoOtherRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "hung", basedOn: nil, createsBranch: true, in: harness.project)
    let hung = try #require(harness.worktree(onBranch: "hung"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let gate = harness.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let fake = try harness.modelWithStatusHeld(until: gate, answering: "hung")
    fake.removalStatusWait = .milliseconds(100)
    await fake.requestWorktreeRemoval(of: hung)?.value
    fake.pendingWorktreeRemoval = nil
    let firstRead = try #require(fake.removalStatusReads[hung.id])

    await fake.requestWorktreeRemoval(of: hung)?.value

    #expect(fake.pendingWorktreeRemoval != nil)
    #expect(fake.removalStatusReads[hung.id] == firstRead)
  }

  @Test func anEarlierRemovalsReadLandingDuringTheNextStillLeavesAReadAfterTheClick()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "slow", basedOn: nil, createsBranch: true, in: harness.project)
    let slow = try #require(harness.worktree(onBranch: "slow"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let gate = harness.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let fake = try harness.modelWithStatusHeld(until: gate, answering: "slow")
    fake.removalStatusWait = .milliseconds(100)
    await fake.requestWorktreeRemoval(of: slow)?.value
    fake.pendingWorktreeRemoval = nil
    fake.removalStatusWait = .seconds(8)

    let second = fake.requestWorktreeRemoval(of: slow)
    try Data().write(to: gate)
    await second?.value

    #expect(harness.statusRunCount() == 2, "the earlier read began before this click")
    #expect(fake.pendingWorktreeRemoval?.hasUnreadChanges == false)
  }

  @Test func aRemovalWhoseStatusReadFailsSaysTheChangesWentUnread() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "refused", basedOn: nil, createsBranch: true, in: harness.project)
    let refused = try #require(harness.worktree(onBranch: "refused"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    let fake = try harness.modelOnFakeGit(
      """
      case "$*" in
        *status*) exit 128 ;;
      esac
      """)

    await fake.requestWorktreeRemoval(of: refused)?.value

    let pending = try #require(fake.pendingWorktreeRemoval)
    #expect(pending.hasUnreadChanges)
  }

  @Test func aPollLandingAfterARemovalBeganIsDropped() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    let model = try harness.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          printf '# branch.head main\\n1 .M N... 100644 100644 100644 a a x.txt\\n' ;;
      esac
      """)
    let main = try #require(harness.worktree(onBranch: "main"))

    let poll = Task { await model.refreshStatuses() }
    try await waitUntil { harness.statusRunCount() > 0 }
    model.worktreeOperations.begin(.preDeleteHook, on: main.id)
    try Data().write(to: gate)
    await poll.value

    #expect(model.statuses[main.id] == nil)
  }
}
