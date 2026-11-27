import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelAllChangesReadsTests {
  @Test func aShownTabReadsTheWorktreesChangesWithThePanelShut() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )

    await harness.model.refreshStatuses()

    try await waitUntil { harness.allChangesPaths(in: tab) == ["README.md"] }
    #expect(harness.allChangesPaths(in: tab) == ["README.md"])
    #expect(!harness.model.showsFilesPanel)
  }

  @Test func underBranchTheTabAsksForTheBranchReadThePanelWouldMake() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "one\ntwo\n"],
      in: feature.path,
      using: harness.git,
    )

    harness.model.setChangeScope(.branch)
    await harness.model.refreshStatuses()

    try await waitUntil { harness.allChangesPaths(in: tab) == ["work.txt"] }
    #expect(harness.allChangesPaths(in: tab) == ["work.txt"])
    #expect(harness.model.branchChanges[feature.id] != nil, "kept with the panel shut")
  }

  @Test func aHiddenTabLetsGoOfItsRowsAndReadsAgainWhenShown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab) == ["README.md"] }

    harness.model.newShellTab()
    #expect(harness.model.allChangesReadings[tab.id] == nil)

    harness.model.activateTab(tab.id)
    try await waitUntil { harness.allChangesPaths(in: tab) == ["README.md"] }
    #expect(harness.allChangesPaths(in: tab) == ["README.md"])
  }

  @Test func aReadLandingAfterItsTabWasHiddenLetsGoOfItsRowsAndKeepsWhatItWasToRead()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab) == ["README.md"] }
    try await waitUntil { harness.model.pendingAllChangesReads.isEmpty }
    harness.model.allChangesStaleFiles.mark(.everything, in: tab.id)
    let read = Task { await harness.model.readAllChangesTab(tab.id) }
    while !harness.model.allChangesReadLog.isReading(tab.id) { await Task.yield() }

    harness.model.newShellTab()
    await read.value

    #expect(harness.model.allChangesReadings[tab.id] == nil)
    #expect(harness.model.allChangesStaleFiles.pending(tab.id) == .everything)
  }

  @Test func aHiddenTabForgetsItsStepsAndAnyStepQueuedForItsView() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.noteChangeSteps(ChangeSteps(hasNext: true, hasPrevious: false), of: tab.id)
    harness.model.stepToChange(.next, in: tab.id)

    harness.model.newShellTab()

    #expect(harness.model.fileTabChangeSteps[tab.id] == nil)
    #expect(harness.model.changeStepRequests[tab.id] == nil)
  }

  @Test func anUnreadFileNearingTheScreenIsReadAtOnceThoughAPacedReadWaits() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.allChangesReadings[tab.id] = .sample([("a.txt", .unread)])
    let paced = Task<Void, Never> {}
    harness.model.pendingAllChangesReads[tab.id] = paced

    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)

    #expect(paced.isCancelled)
    #expect(harness.model.pendingAllChangesReads[tab.id] != paced)
  }

  @Test func anUnreadFileNearingTheScreenOfACoveredWindowIsOwedItsRead() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.allChangesReadings[tab.id] = .sample([("a.txt", .unread)])
    harness.platform.isWorkspaceWindowVisible = false
    let paced = Task<Void, Never> {}
    harness.model.pendingAllChangesReads[tab.id] = paced

    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)

    #expect(harness.model.pendingAllChangesReads[tab.id] == paced)
    #expect(harness.model.allChangesReadLog.owed.contains(tab.id))
  }

  @Test func aFileKeptStaleAwayFromTheScreenIsReadAtOnceAsItNearsIt() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let read = AllChangesReading.sample(rows: [
      ("a.txt", FileTabRows(lines: [], marksStaging: true))
    ])
    var stale = try #require(read.files.first)
    stale.isStale = true
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: read.listed,
      files: [stale],
    )
    harness.model.pendingAllChangesReads.removeValue(forKey: tab.id)?.cancel()

    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)

    #expect(harness.model.pendingAllChangesReads[tab.id] != nil)
  }

  @Test func theComposersFileKeptStaleAwayFromTheScreenIsReadAtOnce() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let rows = FileTabRows(
      lines: [DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "a")],
      marksStaging: true,
    )
    let read = AllChangesReading.sample(rows: [("a.txt", rows), ("b.txt", rows)])
    harness.model.allChangesReadings[tab.id] = read
    harness.model.openReviewComposer(fromRow: 0, toRow: 0, ofSection: 0, side: nil, in: tab.id)
    var stale = read.files[0]
    stale.isStale = true
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: read.listed,
      files: [stale, read.files[1]],
    )
    harness.model.pendingAllChangesReads.removeValue(forKey: tab.id)?.cancel()

    harness.model.noteAllChangesFilesNear(["b.txt"], in: tab.id)

    #expect(harness.model.pendingAllChangesReads[tab.id] != nil)
  }

  @Test func theComposersFileKeptStaleAndCollapsedIsReadAtOnce() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let rows = FileTabRows(
      lines: [DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "a")],
      marksStaging: true,
    )
    let read = AllChangesReading.sample(rows: [("a.txt", rows), ("b.txt", rows)])
    harness.model.allChangesReadings[tab.id] = read
    harness.model.openReviewComposer(fromRow: 0, toRow: 0, ofSection: 0, side: nil, in: tab.id)
    var stale = read.files[0]
    stale.isStale = true
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: read.listed,
      files: [stale, read.files[1]],
    )
    harness.model.allChangesCollapsedFiles[tab.id] = ["a.txt"]
    harness.model.pendingAllChangesReads.removeValue(forKey: tab.id)?.cancel()

    harness.model.noteAllChangesFilesNear(["b.txt"], in: tab.id)

    #expect(harness.model.pendingAllChangesReads[tab.id] != nil)
  }

  @Test func theNextReadIsPacedByTheStaleFilesNearTheScreenAlone() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.allChangesFilesNear[tab.id] = ["a.txt", "b.txt"]

    harness.model.allChangesStaleFiles.mark(
      .paths(Set(["a.txt"] + (0..<500).map { "far\($0).txt" })),
      in: tab.id,
    )

    #expect(harness.model.filesOwed(by: tab.id) == 1)
  }

  @Test func aCollapsedFileNearTheScreenWaitsUnreadUntilItIsExpanded() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.allChangesReadings[tab.id] = .sample([("a.txt", .unread)])
    harness.model.toggleAllChangesFileCollapsed("a.txt", in: tab.id)
    harness.model.pendingAllChangesReads.removeValue(forKey: tab.id)?.cancel()

    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)
    #expect(harness.model.pendingAllChangesReads[tab.id] == nil)

    harness.model.toggleAllChangesFileCollapsed("a.txt", in: tab.id)
    #expect(harness.model.pendingAllChangesReads[tab.id] != nil)
  }

  @Test func aListLandingUnchangedStillReadsWhatAReadWaitingOnItLeftStale() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "a.txt", kind: .modified, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status
    let list = try #require(harness.model.allChangesList(of: harness.main.id))
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: list,
      files: list.map { AllChangesFile(change: $0, content: .unread, signature: nil) },
    )
    harness.model.allChangesStaleFiles.mark(.everything, in: tab.id)
    harness.model.pendingAllChangesReads.removeValue(forKey: tab.id)?.cancel()

    harness.model.noteAllChangesListLanded(in: harness.main.id)

    #expect(harness.model.pendingAllChangesReads[tab.id] != nil)
  }

  @Test func aStatusListingANewFileOwesAReadOfThatFileAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab) == ["README.md"] }
    try await harness.statusReadsSettle(feature)
    try await waitUntil { harness.model.pendingAllChangesReads.isEmpty }
    _ = harness.model.allChangesStaleFiles.take(tab.id)
    try "new\n".write(
      to: feature.path.appending(path: "new.txt"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.pendingAllChangesReads[tab.id] = Task {}

    await harness.model.refreshStatuses()

    #expect(harness.model.allChangesStaleFiles.take(tab.id) == .paths(["new.txt"]))
  }

  @Test func everythingKeptForAClosedTabGoesWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab) != nil }

    harness.model.closeTab(tab.id)

    #expect(harness.model.allChangesReadings.isEmpty)
    #expect(harness.model.pendingAllChangesReads.isEmpty)
  }

  @Test func aReadMovesTheCommentsOfAFileNearTheScreenToFollowTheLinesTheyQuote() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    let readme = feature.path.appending(path: "README.md")
    try "kept\nedited\n".write(to: readme, atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab) == ["README.md"] }
    harness.model.noteAllChangesFilesNear(["README.md"], in: tab.id)
    let comment = ReviewComment.sample(
      path: "README.md",
      lines: 2...2,
      quote: ["edited"],
      text: "Why?",
    )
    harness.model.addReviewComment(comment, in: feature.id)

    try "new\nkept\nedited\n".write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteAllChangesTabChanged(tab.id, staleness: .paths(["README.md"]))

    let moved = { harness.model.reviewComments(in: feature.id).first?.lines }
    try await waitUntil { moved() == 3...3 }
    #expect(moved() == 3...3)
  }

  @Test func aReadMovingCommentsKeepsTheFindSelectionOnItsMatch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    let readme = feature.path.appending(path: "README.md")
    try "q\nedited\n".write(to: readme, atomically: true, encoding: .utf8)
    try "q long\nz\nq\n".write(
      to: feature.path.appending(path: "b.txt"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteAllChangesFilesNear(["README.md", "b.txt"], in: tab.id)
    await harness.model.refreshStatuses()
    try await waitUntil {
      harness.model.allChangesDocument(of: tab.id)?.text.string.contains("q long") == true
    }
    harness.model.addReviewComment(
      ReviewComment.sample(path: "README.md", lines: 2...2, quote: ["edited"], text: "Why?"),
      in: feature.id,
    )
    harness.model.showFind()
    harness.model.setFindText("q", of: tab.id)
    harness.model.findNext(in: tab.id)
    let picked = try #require(harness.model.selectedFileFindMatch(of: tab.id))
    try #require(harness.model.fileFindResults[tab.id]?.matches.count == 3)

    try "1\n2\n3\n4\n5\nq\nedited\n".write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteAllChangesTabChanged(tab.id, staleness: .paths(["README.md"]))

    let moved = { harness.model.reviewComments(in: feature.id).first?.lines }
    try await waitUntil { moved() == 7...7 }
    #expect(harness.model.selectedFileFindMatch(of: tab.id) == picked)
  }

  @Test func aFileScrolledToWhileAReadRunsIsReadAgainIfThatReadLeftItStale() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    for name in ["a.txt", "b.txt"] {
      try "\(name)\n".write(
        to: feature.path.appending(path: name),
        atomically: true,
        encoding: .utf8,
      )
    }
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab)?.count == 2 }
    harness.model.noteAllChangesFilesNear(["a.txt", "b.txt"], in: tab.id)
    try await waitUntil {
      harness.model.allChangesReadings[tab.id]?.files.allSatisfy { $0.rows != nil } == true
    }
    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)
    try await waitUntil { harness.model.pendingAllChangesReads.isEmpty }
    harness.model.allChangesStaleFiles.mark(.everything, in: tab.id)
    let read = Task { await harness.model.readAllChangesTab(tab.id) }
    while !harness.model.allChangesReadLog.isReading(tab.id) { await Task.yield() }

    harness.model.noteAllChangesFilesNear(["b.txt"], in: tab.id)
    await read.value

    let owesB = { harness.model.allChangesReadings[tab.id]?.owesRead("b.txt") }
    try await waitUntil { owesB() == false }
    #expect(owesB() == false)
  }

  @Test func aFileKeptStaleLeavesTheCommentsItsOwnTabMovedWhereThatTabPutThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    let b = feature.path.appending(path: "b.txt")
    try "a\n".write(to: feature.path.appending(path: "a.txt"), atomically: true, encoding: .utf8)
    try "b1\nb2\n".write(to: b, atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab)?.count == 2 }
    harness.model.noteAllChangesFilesNear(["a.txt", "b.txt"], in: tab.id)
    try await waitUntil {
      harness.model.allChangesReadings[tab.id]?.files.allSatisfy { $0.rows != nil } == true
    }
    harness.model.addReviewComment(
      ReviewComment.sample(path: "b.txt", lines: 2...2, quote: ["b2"], text: "Why?"),
      in: feature.id,
    )
    try "x\ny\nb1\nb2\n".write(to: b, atomically: true, encoding: .utf8)
    let rowsOnDisk = ["x", "y", "b1", "b2"].enumerated().map { index, text in
      DiffLine(kind: .added, oldNumber: nil, newNumber: index + 1, text: text)
    }
    harness.model.reanchorReviewComments(
      onFile: "b.txt",
      in: feature.id,
      to: rowsOnDisk,
      readUnder: .modified,
    )
    #expect(harness.model.reviewComments(in: feature.id).first?.lines == 4...4)
    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)
    try await waitUntil { harness.model.pendingAllChangesReads.isEmpty }
    harness.model.allChangesStaleFiles.mark(.everything, in: tab.id)

    await harness.model.readAllChangesTab(tab.id)

    #expect(harness.model.allChangesReadings[tab.id]?.owesRead("b.txt") == true)
    #expect(harness.model.reviewComments(in: feature.id).first?.lines == 4...4)
  }
}
