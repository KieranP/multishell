import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore

extension AppModelWorktreeRemovalTests {
  @Test func askingToRemoveAWorktreeReadsItsStatusFirst() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.requestWorktreeRemoval(of: side)

    try await waitUntil { h.model.pendingWorktreeRemoval != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRemovalThatAsksNothingRequestedTwiceRunsOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let log = h.root.appendingPathComponent("pre-delete.log")
    h.model.updateSettings(
      ProjectSettings(preDeleteHook: "echo ran >> \(log.path)"), for: h.project)
    h.model.setConfirmsWorktreeRemoval(false)
    h.model.setDeletesBranchWithWorktree(true)

    h.model.requestWorktreeRemoval(of: side)
    h.model.requestWorktreeRemoval(of: side)

    try await waitUntil { h.worktree(onBranch: "side") == nil }
    await h.awaitOperationEnd(on: side.id)
    let runs = try String(contentsOf: log, encoding: .utf8)
    #expect(runs == "ran\n")
  }

  @Test func aSlowWorktreeIsStillReadBeforeItsRemovalDialog() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]
    h.model.statusReads.pace = .standard
    h.model.statusReads.remember([side.id: .seconds(10)])

    h.model.requestWorktreeRemoval(of: side)

    try await waitUntil { h.model.pendingWorktreeRemoval != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRowOnScreenThePaceHoldsBackIsStillReadBeforeItsRemovalDialog() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]
    h.model.statusReads.pace = .standard
    h.model.statusReads.remember([side.id: .seconds(3)])

    await h.model.requestWorktreeRemoval(of: side)?.value

    #expect(h.model.pendingWorktreeRemoval != nil)
    #expect(h.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRemovalReadLandingLateLeavesTheDialogThatOpenedMeanwhile() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gated", basedOn: nil, createBranch: true, in: h.project)
    await h.model.createWorktree(branch: "quick", basedOn: nil, createBranch: true, in: h.project)
    let gated = try #require(h.worktree(onBranch: "gated"))
    let quick = try #require(h.worktree(onBranch: "quick"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$PWD $*" in
        *gated*status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done; printf '## gated\\n' ;;
        *quick*status*) printf '## quick\\n' ;;
      esac
      """)

    fake.requestWorktreeRemoval(of: gated)
    try await waitUntil { h.gitCalls().contains { $0.contains("status") } }
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
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gated", basedOn: nil, createBranch: true, in: h.project)
    let gated = try #require(h.worktree(onBranch: "gated"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done; printf '## gated\\n' ;;
      esac
      """)

    fake.requestWorktreeRemoval(of: gated)
    fake.requestWorktreeRemoval(of: gated)
    try await waitUntil { h.statusRunCount() > 0 }
    try Data().write(to: gate)
    try await waitUntil { fake.pendingWorktreeRemoval != nil }

    #expect(h.statusRunCount() == 1)
  }

  @Test func aRemovalWhoseStatusReadHangsStillOpensItsDialog() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "hung", basedOn: nil, createBranch: true, in: h.project)
    let hung = try #require(h.worktree(onBranch: "hung"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ] && [ -d "\(h.root.path)" ]; do sleep 0.02; done
          printf '## hung\\n' ;;
      esac
      """)
    fake.removalStatusWait = .milliseconds(100)

    fake.requestWorktreeRemoval(of: hung)

    try await waitUntil { fake.pendingWorktreeRemoval != nil }
    let pending = try #require(fake.pendingWorktreeRemoval)
    let warning = fake.worktreeRemovalWarning(for: pending)
    #expect(pending.message(warning: warning).contains("could not be read"))
  }

  @Test func askingAgainWhileTheLastRemovalsReadStillHangsStartsNoOtherRead() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "hung", basedOn: nil, createBranch: true, in: h.project)
    let hung = try #require(h.worktree(onBranch: "hung"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ] && [ -d "\(h.root.path)" ]; do sleep 0.02; done
          printf '## hung\\n' ;;
      esac
      """)
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
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)
    let slow = try #require(h.worktree(onBranch: "slow"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ] && [ -d "\(h.root.path)" ]; do sleep 0.02; done
          printf '## slow\\n' ;;
      esac
      """)
    fake.removalStatusWait = .milliseconds(100)
    await fake.requestWorktreeRemoval(of: slow)?.value
    fake.pendingWorktreeRemoval = nil
    fake.removalStatusWait = .seconds(8)

    let second = fake.requestWorktreeRemoval(of: slow)
    try Data().write(to: gate)
    await second?.value

    #expect(h.statusRunCount() == 2, "the earlier read began before this click")
    #expect(fake.pendingWorktreeRemoval?.changesUnread == false)
  }

  @Test func aRemovalWhoseStatusReadFailsSaysTheChangesWentUnread() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "refused", basedOn: nil, createBranch: true, in: h.project)
    let refused = try #require(h.worktree(onBranch: "refused"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) exit 128 ;;
      esac
      """)

    await fake.requestWorktreeRemoval(of: refused)?.value

    let pending = try #require(fake.pendingWorktreeRemoval)
    #expect(pending.changesUnread)
  }

  @Test func aPollLandingAfterARemovalBeganIsDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          printf '# branch.head main\\n1 .M N... 100644 100644 100644 a a x.txt\\n' ;;
      esac
      """)
    let main = try #require(h.worktree(onBranch: "main"))

    let poll = Task { await model.refreshStatuses() }
    try await waitUntil { h.gitCalls().contains { $0.contains("status") } }
    model.worktreeOperations.begin(.preDeleteHook, on: main.id)
    try Data().write(to: gate)
    await poll.value

    #expect(model.statuses[main.id] == nil)
  }
}
