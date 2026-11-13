import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelReviewFilesTests {
  private static func comment(_ text: String = "Guard it.") -> ReviewComment {
    ReviewComment(
      path: "Sources/App.swift",
      side: .onDisk,
      scope: .modified,
      lines: 3...4,
      quote: ["let a = 1", "let b = 2"],
      text: text,
    )
  }

  private func reviewFileNames(in directory: URL) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
  }

  @Test func aCommentWrittenBeforeARelaunchIsThereAfterIt() {
    let harness = Harness()
    let comment = Self.comment()

    harness.model.addReviewComment(comment, in: harness.feature.id)

    let (after, _, _, _) = harness.relaunched()
    #expect(after.reviewComments(in: harness.feature.id) == [comment])
    #expect(after.reviewComments(in: harness.main.id).isEmpty)
  }

  @Test func aSentCommentIsDroppedAtLaunchOnceTheDropsSweepHasTakenItsFile() {
    let harness = Harness()
    let old = Self.comment("old")
    let recent = Self.comment("recent")
    let pending = Self.comment("pending")
    let now = Date()
    harness.model.addReviewComment(old, in: harness.feature.id)
    harness.model.addReviewComment(recent, in: harness.feature.id)
    harness.model.addReviewComment(pending, in: harness.feature.id)
    harness.model.markReviewCommentsSent(
      [old.id],
      in: harness.feature.id,
      to: "Codex",
      at: now - DropCopies.retention - 60,
    )
    harness.model.markReviewCommentsSent([recent.id], in: harness.feature.id, to: "Codex", at: now)

    let (after, _, _, _) = harness.relaunched()

    #expect(after.reviewComments(in: harness.feature.id).map(\.text) == ["recent", "pending"])
  }

  @Test func aReviewFileSavedDoesNotReopenTheStateFilesFailureAlert() {
    let harness = Harness()
    let failure = Result<Void, any Error>.failure(CocoaError(.fileWriteNoPermission))
    harness.model.presentedError = nil
    harness.model.recordSaveOutcome(failure)
    #expect(harness.model.presentedError != nil)
    harness.model.presentedError = nil

    harness.model.recordReviewSaveOutcome(.success(()))
    harness.model.recordSaveOutcome(failure)

    #expect(harness.model.presentedError == nil)
  }

  @Test func quittingRewritesNoReviewFileThatHasNotChanged() throws {
    let harness = Harness()
    let file = ReviewFile(worktreeID: harness.feature.id, in: harness.reviews)
    try file.save([Self.comment()], as: file.issueTicket())
    let name = try #require(reviewFileNames(in: harness.reviews).first)
    let path = harness.reviews.appendingPathComponent(name).path
    let longAgo = Date(timeIntervalSince1970: 1_000_000)
    try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: path)
    let (after, _, _, _) = harness.relaunched()
    #expect(after.reviewComments(in: harness.feature.id).count == 1)

    after.writeReviewCommentsNow()

    let written = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate]
    #expect(written as? Date == longAgo)
  }

  @Test func loadingDropsAWeekOldSentCommentWithoutRewritingTheFile() throws {
    let harness = Harness()
    var old = Self.comment("old")
    old.markSent(to: "Codex", at: Date() - DropCopies.retention - 60)
    let file = ReviewFile(worktreeID: harness.feature.id, in: harness.reviews)
    try file.save([old, Self.comment("pending")], as: file.issueTicket())
    let name = try #require(reviewFileNames(in: harness.reviews).first)
    let path = harness.reviews.appendingPathComponent(name).path
    let longAgo = Date(timeIntervalSince1970: 1_000_000)
    try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: path)

    let (after, _, _, _) = harness.relaunched()
    after.writeReviewCommentsNow()

    #expect(after.reviewComments(in: harness.feature.id).map(\.text) == ["pending"])
    let written = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate]
    #expect(written as? Date == longAgo)
  }

  @Test func aReviewFileThatWillNotReadIsSaidAtLaunch() throws {
    let harness = Harness()
    let file = ReviewFile(worktreeID: harness.feature.id, in: harness.reviews)
    try file.save([Self.comment()], as: file.issueTicket())
    let name = try #require(reviewFileNames(in: harness.reviews).first)
    try Data("not json".utf8).write(to: harness.reviews.appendingPathComponent(name))

    let (after, _, _, _) = harness.relaunched()

    #expect(after.presentedError != nil)
  }

  @Test func everyReviewFileThatWillNotReadIsNamedInOneAlert() throws {
    let harness = Harness()
    for worktree in [harness.main, harness.feature] {
      let file = ReviewFile(worktreeID: worktree.id, in: harness.reviews)
      try file.save([Self.comment()], as: file.issueTicket())
    }
    for name in reviewFileNames(in: harness.reviews) {
      try Data("not json".utf8).write(to: harness.reviews.appendingPathComponent(name))
    }

    let (after, _, _, _) = harness.relaunched()

    let backups = reviewFileNames(in: harness.reviews)
    #expect(backups.count == 2)
    let message = try #require(after.presentedError?.message)
    #expect(backups.allSatisfy(message.contains))
  }

  @Test func aWorktreeListedAfterLaunchShowsTheCommentsSavedForItsPath() throws {
    let harness = Harness()
    let added = Worktree(
      path: harness.root.appending(path: "added"),
      projectID: harness.project.id,
      head: "c",
      branch: "added",
    )
    let file = ReviewFile(worktreeID: added.id, in: harness.reviews)
    try file.save([Self.comment("Saved before.")], as: file.issueTicket())
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, added],
      forProject: harness.project.id,
    )

    harness.model.readReviewFilesOfNewWorktrees()
    harness.model.addReviewComment(Self.comment("Added now."), in: added.id)
    harness.model.writeReviewCommentsNow()

    #expect(
      harness.model.reviewComments(in: added.id).map(\.text) == ["Saved before.", "Added now."]
    )
    #expect(try file.load().map(\.text) == ["Saved before.", "Added now."])
  }

  @Test func removingAProjectLeavesItsReviewFilesForTheProjectAddedAgain() throws {
    let harness = Harness()
    harness.model.addReviewComment(Self.comment(), in: harness.feature.id)
    harness.model.writeReviewCommentsNow()

    harness.model.removeProject(harness.project)
    harness.model.writeReviewCommentsNow()

    #expect(reviewFileNames(in: harness.reviews).count == 1)
    let project = harness.store.addProject(at: harness.root)
    harness.store.replaceWorktrees([harness.main, harness.feature], forProject: project.id)
    harness.model.readReviewFilesOfNewWorktrees()
    #expect(harness.model.reviewComments(in: harness.feature.id).map(\.text) == ["Guard it."])
  }

  @Test func aFileKeepingNothingForANewWorktreeRedrawsNothing() throws {
    let harness = Harness()
    let added = Worktree(
      path: harness.root.appending(path: "added"),
      projectID: harness.project.id,
      head: "c",
      branch: "added",
    )
    var old = Self.comment()
    old.markSent(to: "Codex", at: Date() - DropCopies.retention - 60)
    let file = ReviewFile(worktreeID: added.id, in: harness.reviews)
    try file.save([old], as: file.issueTicket())
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, added],
      forProject: harness.project.id,
    )
    let wrote = AtomicFlag()
    withObservationTracking {
      _ = harness.model.reviewComments
    } onChange: {
      wrote.raise()
    }

    harness.model.readReviewFilesOfNewWorktrees()

    #expect(!wrote.raised)
  }

  @Test func removingAProjectWritesItsReviewFilesChangesFirst() throws {
    let harness = Harness()
    harness.model.addReviewComment(Self.comment(), in: harness.feature.id)

    harness.model.removeProject(harness.project)

    let file = ReviewFile(worktreeID: harness.feature.id, in: harness.reviews)
    #expect(try file.load().map(\.text) == ["Guard it."])
  }
}
