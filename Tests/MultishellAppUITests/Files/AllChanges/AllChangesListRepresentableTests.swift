import AppKit
import MultishellGitKit
import SwiftUI
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct AllChangesListRepresentableTests {
  private static func file(
    _ path: String,
    _ lines: [DiffLine],
    kind: StatusChange.Kind,
  )
    -> AllChangesFile
  {
    AllChangesFile(
      change: AllChangesFileChange(path: path, kind: kind, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(FileTabRows(lines: lines, marksStaging: true)),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
  }

  private static func modified(_ path: String, rows: Int) -> AllChangesFile {
    file(
      path,
      (1...rows).map { line in
        DiffLine(
          kind: line == rows / 2 ? .added : .context,
          oldNumber: line == rows / 2 ? nil : line,
          newNumber: line,
          text: "\(path) \(line)",
        )
      },
      kind: .modified,
    )
  }

  private static func added(_ path: String, rows: Int) -> AllChangesFile {
    file(
      path,
      (1...rows).map { number in
        DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: path)
      },
      kind: .added,
    )
  }

  private static func shown(
    _ files: [AllChangesFile],
    harness: ModelHarness,
    tab: AllChangesTab,
    layout: FileTabLayout = .unified,
  ) -> (AllChangesListView, NSHostingView<AllChangesListRepresentable>, NSWindow) {
    let document = AllChangesDocument(
      AllChangesReading(listed: files.map(\.change), files: files),
      collapsed: [],
      heldOpen: [:],
      layout: layout,
    )
    let host = NSHostingView(
      rootView: AllChangesListRepresentable(
        model: harness.model,
        tab: tab,
        document: document,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 700, height: 240)
    let window = OffscreenWindow.holding(host, deferred: false)
    host.layoutSubtreeIfNeeded()
    let list = host.descendants(of: AllChangesListView.self).first!
    return (list, host, window)
  }

  @Test func eachFileNearTheScreenIsItsOwnViewHoldingItsShownRows() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown(
      [Self.modified("a.txt", rows: 9), Self.modified("b.txt", rows: 9)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    let first = list.file(at: 0)?.mainColumn.textView.displayText.lines.map(\.text)
    let second = list.file(at: 1)?.mainColumn.textView.displayText.lines.map(\.text)

    #expect(first?.allSatisfy { $0.hasPrefix("a.txt") } == true)
    #expect(second?.allSatisfy { $0.hasPrefix("b.txt") } == true)
  }

  @Test func theFileLitInSplitFollowsTheScrollInOrderThoughSomeFilesAreShownWhole() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let files =
      [Self.modified("a.txt", rows: 9)]
      + ["b.txt", "c.txt", "d.txt"].map { Self.added($0, rows: 20) }
      + [Self.modified("f.txt", rows: 9)]
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab, layout: .split)
    defer { withExtendedLifetime(window) {} }
    let order = files.map(\.path)
    var lit: [String] = []

    while list.scrollY + list.clipHeight < list.scrollView.documentView!.frame.height - 1 {
      list.scroll(toY: list.scrollY + 15)
      host.layoutSubtreeIfNeeded()
      if let path = harness.model.allChangesTopFile(of: tab.id)?.path, path != lit.last {
        lit.append(path)
      }
    }

    #expect(lit.count > 2 && lit == Array(order.prefix(lit.count)), "lit: \(lit)")
  }

  @Test func theArrowsStepFromOneFilesChangeToTheNextFilesAcrossTheList() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.modified("a.txt", rows: 9), Self.modified("b.txt", rows: 9)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    for _ in 0..<2 {
      harness.model.stepToChange(.next, in: tab.id)
      host.rootView = host.rootView
      host.layoutSubtreeIfNeeded()
    }

    #expect(list.file(at: 0)?.mainColumn.textView.steppedChange == nil)
    #expect(list.file(at: 1)?.mainColumn.textView.steppedChange != nil)
  }

  @Test func cmdDownGoesToTheListsEndFromAnyFile() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<6).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    list.file(at: 0)?.mainColumn.textView.moveToEndOfDocument(nil)
    host.layoutSubtreeIfNeeded()

    let end = list.scrollView.documentView!.frame.height - list.clipHeight
    #expect(abs(list.scrollY - end) < 1)
  }

  @Test func scrollingThroughManyFilesReusesAFewViewsRatherThanBuildingOneAFile() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<80).map { Self.modified("f\($0).txt", rows: 9) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    var seen: Set<ObjectIdentifier> = []

    while list.scrollY + list.clipHeight < list.scrollView.documentView!.frame.height - 1 {
      list.scroll(toY: list.scrollY + 60)
      host.layoutSubtreeIfNeeded()
      for view in host.descendants(of: AllChangesFileView.self) {
        seen.insert(ObjectIdentifier(view))
      }
    }

    #expect(seen.count < 20, "\(seen.count) views built for 80 files")
  }

  @Test func aViewReusedForAnotherFileStartsAtItsLeftEdge() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let wide = String(repeating: "x", count: 400)
    let files = (0..<40).map { index in
      Self.file(
        "f\(index).txt",
        [DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: wide)],
        kind: .modified,
      )
    }
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let first = list.file(at: 0)!
    first.diffView.scroll(to: NSPoint(x: 200, y: 0))
    host.layoutSubtreeIfNeeded()
    #expect(first.diffView.scrollOrigin.x > 0)

    var offsetsWhenReused: [CGFloat] = []
    while list.scrollY + list.clipHeight < list.scrollView.documentView!.frame.height - 1 {
      list.scroll(toY: list.scrollY + 30)
      host.layoutSubtreeIfNeeded()
      for (index, view) in list.builtFiles where index > 0 && view === first {
        offsetsWhenReused.append(first.diffView.scrollOrigin.x)
      }
    }

    #expect(!offsetsWhenReused.isEmpty)
    #expect(offsetsWhenReused.allSatisfy { $0 == 0 })
  }

  @Test func aFilesRowsRunFlushToItsBoxWithNoInsetAboveOrBelow() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown([Self.added("a.txt", rows: 4)], harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let file = list.file(at: 0)!
    let geometry = file.mainColumn.textView.geometry

    #expect(geometry.top(ofRow: 0) == 0)
    #expect(file.diffView.frame.height == 4 * geometry.rowHeight)
  }

  @Test func aTabShownAgainReturnsToTheSameLineHoweverOftenItIsShown() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let files = (0..<4).map { Self.modified("f\($0).txt", rows: 30) }
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    let fileTop = list.top(ofFile: 2)!
    list.scroll(toY: fileTop + AllChangesFileView.headerHeight + 40)
    host.layoutSubtreeIfNeeded()
    OffscreenWindow.settle(within: 0.1)
    let left = list.scrollY
    window.contentView = nil
    var returnedTo: [CGFloat] = []

    for _ in 0..<3 {
      let (again, _, window) = Self.shown(files, harness: harness, tab: tab)
      OffscreenWindow.settle(within: 0.1)
      returnedTo.append(again.scrollY)
      window.contentView = nil
    }

    #expect(returnedTo.allSatisfy { abs($0 - left) < 1 }, "left at \(left), back at \(returnedTo)")
  }

  @Test func aDragUpTheGutterOpensTheComposerOnTheRowsItCrossed() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = [Self.modified("a.txt", rows: 9)]
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let (list, _, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let column = try #require(list.file(at: 0)?.mainColumn)

    column.onCommentOnRows?(5, 2, nil)

    let composer = try #require(harness.model.reviewComposers[tab.id])
    #expect(composer.path == "a.txt")
  }

  @Test func cmdUpStillGoesToTheTopAfterTheFocusedFileScrolledAway() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<20).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let first = try #require(list.file(at: 0)?.mainColumn.textView)
    window.makeFirstResponder(first)
    first.moveToEndOfDocument(nil)
    host.layoutSubtreeIfNeeded()

    let handled = window.firstResponder?.tryToPerform(
      #selector(NSResponder.moveToBeginningOfDocument(_:)),
      with: nil,
    )
    host.layoutSubtreeIfNeeded()

    #expect(handled == true)
    #expect(list.scrollY == 0)
  }

  @Test func theNextArrowStepsIntoAFileStillToBeReadSoItIsRead() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let unread = AllChangesFile(
      change: AllChangesFileChange(path: "b.txt", kind: .modified, lineCounts: nil),
      content: .unread,
      signature: nil,
    )
    let (list, host, window) = Self.shown(
      [Self.modified("a.txt", rows: 9), unread, Self.modified("c.txt", rows: 9)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    for _ in 0..<2 {
      harness.model.stepToChange(.next, in: tab.id)
      host.rootView = host.rootView
      host.layoutSubtreeIfNeeded()
    }

    let unreadTop = list.top(ofFile: 1) ?? -1
    #expect(
      unreadTop >= list.scrollY && unreadTop < list.scrollY + list.clipHeight / 2,
      "scrollY \(list.scrollY) tops \((0..<3).map { list.top(ofFile: $0) ?? -1 })",
    )
  }

  @Test func aFileShownAfterTheThemeChangesTakesTheNewThemesBorder() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.modified("a.txt", rows: 9)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let next = try #require(
      Theme.builtins.first { $0.fileTab.border != host.rootView.theme.fileTab.border }
    )

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: host.rootView.document,
      theme: next,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    let border = try #require(list.file(at: 0)?.layer?.borderColor)
    #expect(border == NSColor(next.fileTab.border).cgColor)
  }

  @Test func aFileListedAfterTheListWasMadeIsBuiltFromTheNewDocument() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.modified("a.txt", rows: 3)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let files = [Self.modified("a.txt", rows: 3), Self.modified("b.txt", rows: 3)]

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: AllChangesDocument(
        AllChangesReading(listed: files.map(\.change), files: files),
        collapsed: [],
        heldOpen: [:],
        layout: .unified,
      ),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    let second = list.file(at: 1)?.mainColumn.textView.displayText.lines.map(\.text)
    #expect(second?.allSatisfy { $0.hasPrefix("b.txt") } == true)
  }

  @Test func aScrollAwayFromASavedFileStillToBeReadStaysWhereItWent() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let unread = AllChangesFile(
      change: AllChangesFileChange(path: "u.txt", kind: .modified, lineCounts: nil),
      content: .unread,
      signature: nil,
    )
    let files = (0..<8).map { Self.modified("f\($0).txt", rows: 30) } + [unread]
    harness.model.noteAllChangesScrolled(
      tab.id,
      to: AllChangesScroll(
        path: "u.txt",
        scroll: FileTabScroll(line: 1, isCommittedLine: false, rowsFromLine: 0, x: 0),
      ),
    )
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    #expect(list.scrollY > 0)

    list.scroll(toY: 0)
    host.rootView = host.rootView
    host.layoutSubtreeIfNeeded()

    #expect(list.scrollY == 0)
  }

  @Test func theListOffersOneChangesRotorThatWalksOnIntoTheNextFile() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown(
      [Self.modified("a.txt", rows: 9), Self.modified("b.txt", rows: 9)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let rotor = try #require(list.accessibilityCustomRotors().first)
    let delegate = try #require(rotor.itemSearchDelegate)
    let forward = NSAccessibilityCustomRotor.SearchParameters()
    forward.searchDirection = .next

    let first = try #require(delegate.rotor(rotor, resultFor: forward))
    forward.currentItem = first
    let second = try #require(delegate.rotor(rotor, resultFor: forward))

    #expect(list.accessibilityCustomRotors().count == 1)
    #expect(list.file(at: 0)?.mainColumn.textView.accessibilityCustomRotors().isEmpty == true)
    #expect(first.targetElement === list.file(at: 0)?.mainColumn.textView)
    #expect(second.targetElement === list.file(at: 1)?.mainColumn.textView)
    #expect(second.customLabel?.hasPrefix("Added") == true)
  }

  @Test func theKeyboardHandedToTheShownTabIsTakenByItsList() async throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown(
      [Self.modified("a.txt", rows: 9)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    harness.model.fileTabFocusRequest = tab.id
    try await waitUntil { window.firstResponder === list }

    #expect(window.firstResponder === list)
  }

  @Test func aFileListedWhereAnotherWasIsReportedNearTheScreen() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (_, host, window) = Self.shown(
      [Self.modified("b.txt", rows: 3)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let files = [Self.modified("a.txt", rows: 3)]

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: AllChangesDocument(
        AllChangesReading(listed: files.map(\.change), files: files),
        collapsed: [],
        heldOpen: [:],
        layout: .unified,
      ),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    #expect(harness.model.allChangesFilesNear[tab.id] == ["a.txt"])
  }

  @Test func aClickedFileTooNearTheEndToReachTheTopStaysLit() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = (0..<12).map { Self.modified("f\($0).txt", rows: 3) }
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    harness.model.showFileInAllChangesTab("f11.txt", in: worktree.id)
    host.rootView = host.rootView
    host.layoutSubtreeIfNeeded()

    #expect(list.scrollY > 0)
    #expect(harness.model.allChangesTopFile(of: tab.id)?.path == "f11.txt")
  }

  @Test func switchingToSplitKeepsTheFileAtTheTop() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let files = (0..<10).map { index in
      Self.file(
        "f\(index).txt",
        (1...6).map { (number: Int) in
          DiffLine(kind: .removed, oldNumber: number, newNumber: nil, text: "old \(number)")
        }
          + (1...6).map { (number: Int) in
            DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: "new \(number)")
          },
        kind: .modified,
      )
    }
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    list.scroll(toY: try #require(list.top(ofFile: 5)) + 4)
    host.layoutSubtreeIfNeeded()

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: AllChangesDocument(
        AllChangesReading(listed: files.map(\.change), files: files),
        collapsed: [],
        heldOpen: [:],
        layout: .split,
      ),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    #expect(list.fileIndex(at: list.scrollY) == 5)
  }

  @Test func filesMeasuredBeforeEveryFileCollapsedTakeTheirCollapsedHeight() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let files = (0..<30).map { Self.modified("f\($0).txt", rows: 9) }
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    while list.scrollY + list.clipHeight < list.scrollView.documentView!.frame.height - 1 {
      list.scroll(toY: list.scrollY + 60)
      host.layoutSubtreeIfNeeded()
    }
    list.scroll(toY: 0)
    host.layoutSubtreeIfNeeded()

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: AllChangesDocument(
        AllChangesReading(listed: files.map(\.change), files: files),
        collapsed: Set(files.map(\.path)),
        heldOpen: [:],
        layout: .unified,
      ),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    let gap = CGFloat(UIMetrics.allChangesFileGap)
    #expect(list.top(ofFile: 29) == gap + 29 * (AllChangesFileView.headerHeight + gap))
  }

  @Test func aThemeChangeColoursTheBuiltFilesAgain() async throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let swift = Self.file(
      "a.swift",
      (1...5).map { (number: Int) in
        DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: "let value = \(number)")
      },
      kind: .added,
    )
    let (list, host, window) = Self.shown([swift], harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    try await waitUntil { textView.appliedRuns?.isEmpty == false }
    let next = try #require(Theme.builtins.first { $0 != host.rootView.theme })

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: host.rootView.document,
      theme: next,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()
    try await waitUntil { textView.appliedRuns?.isEmpty == false }

    #expect(textView.appliedRuns?.isEmpty == false)
  }

  @Test func aTabLeftWithACollapsedFileAtTheTopReturnsToThatFile() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let files = (0..<6).map { Self.modified("f\($0).txt", rows: 30) }
    let document = AllChangesDocument(
      AllChangesReading(listed: files.map(\.change), files: files),
      collapsed: ["f2.txt"],
      heldOpen: [:],
      layout: .unified,
    )
    let show = {
      let host = NSHostingView(
        rootView: AllChangesListRepresentable(
          model: harness.model,
          tab: tab,
          document: document,
          theme: Theme.builtins[0],
          font: FileFont(family: nil, size: 12),
          find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
        )
      )
      host.frame = NSRect(x: 0, y: 0, width: 700, height: 240)
      let window = OffscreenWindow.holding(host, deferred: false)
      host.layoutSubtreeIfNeeded()
      return (host.descendants(of: AllChangesListView.self).first!, host, window)
    }
    let (list, host, window) = show()
    list.scroll(toY: try #require(list.top(ofFile: 2)))
    host.layoutSubtreeIfNeeded()
    window.contentView = nil

    let (again, _, secondWindow) = show()
    defer { withExtendedLifetime(secondWindow) {} }
    OffscreenWindow.settle(within: 0.1)

    #expect(harness.model.allChangesScroll(of: tab.id)?.path == "f2.txt")
    #expect(again.fileIndex(at: again.scrollY) == 2)
  }

  @Test func theBoxedChangeStaysOnItsLinesWhenAFoldAboveItOpens() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let lines = (1...24).map { (number: Int) -> DiffLine in
      let isChange = number == 1 || number == 21
      return DiffLine(
        kind: isChange ? .added : .context,
        oldNumber: isChange ? nil : number,
        newNumber: number,
        text: number == 21 ? "second" : "line \(number)",
      )
    }
    let files = [Self.file("a.txt", lines, kind: .modified)]
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    for _ in 0..<2 {
      harness.model.stepToChange(.next, in: tab.id)
      host.rootView = host.rootView
      host.layoutSubtreeIfNeeded()
    }
    let before = try #require(list.file(at: 0)?.mainColumn.textView)
    #expect(before.steppedChange.map { before.displayText.lines[$0.lowerBound].text } == "second")

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: AllChangesDocument(
        AllChangesReading(listed: files.map(\.change), files: files),
        collapsed: [],
        heldOpen: ["a.txt": [AllChangesLineSpan(side: .onDisk, lines: 5...17)]],
        layout: .unified,
      ),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    let boxed = try #require(textView.steppedChange)
    #expect(textView.displayText.lines[boxed.lowerBound].text == "second")
  }

  @Test func scrollingTheListClearsTheGuttersPlusItCarriedAway() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<6).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let gutter = try #require(list.file(at: 0)?.mainColumn.gutter)
    gutter.hoveredRow = 3

    list.scroll(toY: 40)
    host.layoutSubtreeIfNeeded()

    #expect(gutter.hoveredRow == nil)
  }

  @Test func aComposerOpenedOnARowScrollsOnlyAsFarAsShowsItsCard() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = (0..<3).map { Self.added("f\($0).txt", rows: 30) }
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    harness.model.openReviewComposer(fromRow: 6, toRow: 6, ofSection: 0, side: nil, in: tab.id)
    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: try #require(harness.model.allChangesDocument(of: tab.id)),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    let composer = try #require(harness.model.reviewComposers[tab.id])
    let column = try #require(list.file(at: 0)?.mainColumn)
    let span = try #require(column.reviewCards.span(of: .composer(composer.id)))
    let fileTop = try #require(list.top(ofFile: 0)) + AllChangesFileView.headerHeight
    #expect(list.scrollY == max(0, fileTop + span.upperBound - list.clipHeight))
  }

  @Test func aCommentPickedInReviewOnAFileFarBelowShowsItsCardInView() async throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = (0..<6).map { Self.added("f\($0).txt", rows: 30) }
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let comment = ReviewComment(
      path: "f4.txt",
      side: .onDisk,
      scope: .modified,
      lines: 10...10,
      quote: ["f4.txt"],
      text: "Look.",
    )
    harness.model.addReviewComment(comment, in: worktree.id)

    await harness.model.selectReviewComment(comment.id, in: worktree.id)
    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: try #require(harness.model.allChangesDocument(of: tab.id)),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()
    await Task.yield()
    host.layoutSubtreeIfNeeded()

    let view = try #require(list.file(at: 4))
    let span = try #require(view.mainColumn.reviewCards.span(of: .comment(comment.id)))
    let cardTop =
      try #require(list.top(ofFile: 4)) + AllChangesFileView.headerHeight
      + span.lowerBound
    #expect(span.upperBound - span.lowerBound > 20, "measured")
    #expect(cardTop >= list.scrollY && cardTop < list.scrollY + list.clipHeight)
  }

  @Test func aCommentPickedInReviewOnACollapsedFileShowsItsCardInView() async throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = (0..<6).map { Self.added("f\($0).txt", rows: 30) }
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let comment = ReviewComment(
      path: "f4.txt",
      side: .onDisk,
      scope: .modified,
      lines: 10...10,
      quote: ["f4.txt"],
      text: "Look.",
    )
    harness.model.addReviewComment(comment, in: worktree.id)
    for index in 0..<6 { harness.model.toggleAllChangesFileCollapsed("f\(index).txt", in: tab.id) }
    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: try #require(harness.model.allChangesDocument(of: tab.id)),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    await harness.model.selectReviewComment(comment.id, in: worktree.id)
    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: try #require(harness.model.allChangesDocument(of: tab.id)),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()
    await Task.yield()
    host.layoutSubtreeIfNeeded()

    let view = try #require(list.file(at: 4))
    let span = try #require(view.mainColumn.reviewCards.span(of: .comment(comment.id)))
    let cardTop =
      try #require(list.top(ofFile: 4)) + AllChangesFileView.headerHeight
      + span.lowerBound
    #expect(span.upperBound - span.lowerBound > 20, "measured")
    #expect(cardTop >= list.scrollY && cardTop < list.scrollY + list.clipHeight)
  }

  @Test func aCommentPickedInReviewOnAnUnreadFileShowsItsCardInViewOnceRead() async throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = (0..<6).map { Self.added("f\($0).txt", rows: 30) }
    var unread = files
    unread[4] = AllChangesFile(change: files[4].change, content: .unread, signature: nil)
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: unread,
    )
    let (list, host, window) = Self.shown(unread, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let comment = ReviewComment(
      path: "f4.txt",
      side: .onDisk,
      scope: .modified,
      lines: 10...10,
      quote: ["f4.txt"],
      text: "Look.",
    )
    harness.model.addReviewComment(comment, in: worktree.id)
    let update = {
      host.rootView = AllChangesListRepresentable(
        model: harness.model,
        tab: tab,
        document: try #require(harness.model.allChangesDocument(of: tab.id)),
        theme: host.rootView.theme,
        font: host.rootView.font,
        find: host.rootView.find,
      )
      host.layoutSubtreeIfNeeded()
    }

    await harness.model.selectReviewComment(comment.id, in: worktree.id)
    try update()
    await Task.yield()
    host.layoutSubtreeIfNeeded()
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    try update()
    await Task.yield()
    host.layoutSubtreeIfNeeded()

    let view = try #require(list.file(at: 4))
    let span = try #require(view.mainColumn.reviewCards.span(of: .comment(comment.id)))
    let cardTop =
      try #require(list.top(ofFile: 4)) + AllChangesFileView.headerHeight
      + span.lowerBound
    #expect(span.upperBound - span.lowerBound > 20, "measured")
    #expect(cardTop >= list.scrollY && cardTop < list.scrollY + list.clipHeight)
  }

  @Test func aCommentPickedInReviewIsRevealedWithNoOtherChangeToTheTab() async throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = (0..<6).map { Self.added("f\($0).txt", rows: 30) }
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let comment = ReviewComment(
      path: "f4.txt",
      side: .onDisk,
      scope: .modified,
      lines: 10...10,
      quote: ["f4.txt"],
      text: "Look.",
    )
    harness.model.addReviewComment(comment, in: worktree.id)
    let (_, _, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    await harness.model.selectReviewComment(comment.id, in: worktree.id)
    try await waitUntil({ harness.model.reviewCardRevealRequests[tab.id] == nil }, seconds: 2)

    #expect(harness.model.reviewCardRevealRequests[tab.id] == nil, "taken by an update")
  }

  @Test func theChangesRotorStepsOnFromItsItemAfterItsViewWasReusedForAnotherFile() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<30).map { Self.modified("f\($0).txt", rows: 9) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let rotor = try #require(list.changesRotor)
    let custom = NSAccessibilityCustomRotor(label: "Changes", itemSearchDelegate: rotor)
    let parameters = NSAccessibilityCustomRotor.SearchParameters()
    parameters.searchDirection = .next
    let first = try #require(rotor.rotor(custom, resultFor: parameters))
    list.scroll(toY: list.scrollView.documentView!.frame.height)
    host.layoutSubtreeIfNeeded()

    parameters.currentItem = first
    let next = try #require(rotor.rotor(custom, resultFor: parameters))

    #expect(next.targetElement === list.file(at: 1)?.mainColumn.textView)
  }

  @Test func anotherFileShownAnewLeavesTheSelectionMadeInOneFile() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (_, host, window) = Self.shown(
      [Self.modified("a.txt", rows: 3), Self.modified("b.txt", rows: 3)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    harness.model.noteFileTabSelection("a.txt 1", of: tab.id)
    let files = [Self.modified("a.txt", rows: 3), Self.modified("b.txt", rows: 4)]

    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: AllChangesDocument(
        AllChangesReading(listed: files.map(\.change), files: files),
        collapsed: [],
        heldOpen: [:],
        layout: .unified,
      ),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    #expect(harness.model.fileTabSelections[tab.id] == "a.txt 1")
  }

  @Test func aFocusedFileLetGoOfLeavesNoSelectionForFindToTake() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<20).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let first = try #require(list.file(at: 0)?.mainColumn.textView)
    window.makeFirstResponder(first)
    first.setSelectedRange(NSRange(location: 0, length: 4))
    #expect(harness.model.fileTabSelections[tab.id] != nil)

    list.scroll(toY: try #require(list.top(ofFile: 15)))
    host.layoutSubtreeIfNeeded()

    #expect(list.file(at: 0) == nil)
    #expect(harness.model.fileTabSelections[tab.id] == nil)
  }

  @Test func theCaretMovedBelowTheClipScrollsTheListToIt() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.added("a.txt", rows: 40)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    let last = textView.displayText.range(ofRow: 39)

    textView.scrollRangeToVisible(NSRange(last))
    host.layoutSubtreeIfNeeded()

    let rowTop =
      try #require(list.top(ofFile: 0)) + AllChangesFileView.headerHeight
      + textView.geometry.top(ofRow: 39)
    #expect(rowTop >= list.scrollY && rowTop < list.scrollY + list.clipHeight)
  }

  @Test(arguments: [#selector(NSResponder.pageDown(_:)), #selector(NSResponder.moveDown(_:))])
  func theListHoldingTheKeyboardScrollsDownForPageAndArrowKeys(command: Selector) {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown(
      (0..<6).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    let handled = list.tryToPerform(command, with: nil)

    #expect(handled)
    #expect(list.scrollY > 0)
  }

  @Test func pageDownInAFocusedFilesTextScrollsTheList() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.added("a.txt", rows: 200)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    window.makeFirstResponder(textView)

    textView.scrollPageDown(nil)
    host.layoutSubtreeIfNeeded()

    #expect(list.scrollY > 0)
  }

  @Test func aCaretScrolledUpIntoViewStopsBelowTheStickyHeader() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.added("a.txt", rows: 200)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    let rowsTop = try #require(list.top(ofFile: 0)) + AllChangesFileView.headerHeight
    list.scroll(toY: rowsTop + textView.geometry.top(ofRow: 100))
    host.layoutSubtreeIfNeeded()

    textView.scrollRangeToVisible(NSRange(textView.displayText.range(ofRow: 99)))
    host.layoutSubtreeIfNeeded()

    let rowTop = rowsTop + textView.geometry.top(ofRow: 99)
    #expect(rowTop >= list.scrollY + AllChangesFileView.headerHeight)
  }

  @Test func aPageDownKeepsTheLastRowsInSightBelowTheStickyHeader() {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown(
      [Self.added("a.txt", rows: 200)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    list.scroll(toY: 200)
    let oldBottom = list.scrollY + list.clipHeight

    list.pageDown(nil)

    #expect(list.scrollY + AllChangesFileView.headerHeight < oldBottom)
  }

  @Test func underLegacyScrollersTheBoxesEndWhereTheStickyHeaderDoes() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<6).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }

    list.scrollView.scrollerStyle = .legacy
    list.scrollView.tile()
    host.layoutSubtreeIfNeeded()

    let scrollView = list.scrollView
    #expect(scrollView.contentView.frame.maxX == scrollView.bounds.width - list.scrollerMargin)
  }

  @Test func endInAFocusedFilesTextGoesToTheListsEnd() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      (0..<6).map { Self.modified("f\($0).txt", rows: 30) },
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    window.makeFirstResponder(textView)

    textView.scrollToEndOfDocument(nil)
    host.layoutSubtreeIfNeeded()

    let end = list.scrollView.documentView!.frame.height - list.clipHeight
    #expect(abs(list.scrollY - end) < 1)
  }

  @Test func optionPageDownInAFocusedFileMovesTheCaretAboutAScreen() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, host, window) = Self.shown(
      [Self.added("a.txt", rows: 300)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    window.makeFirstResponder(textView)
    textView.setSelectedRange(NSRange(location: 0, length: 0))

    textView.pageDown(nil)
    host.layoutSubtreeIfNeeded()

    let row = textView.displayText.row(atOffset: textView.selectedRange().location)
    #expect(row > 0 && row < 40, "caret on row \(row)")
  }

  @Test func aStepLeavesItsContextRowsInSightBelowTheStickyHeader() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let lines = (1...200).map { (number: Int) -> DiffLine in
      let isChange = number.isMultiple(of: 10)
      return DiffLine(
        kind: isChange ? .added : .context,
        oldNumber: isChange ? nil : number,
        newNumber: number,
        text: "line \(number)",
      )
    }
    let files = [Self.file("a.txt", lines, kind: .modified)]
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    for _ in 0..<10 {
      harness.model.stepToChange(.next, in: tab.id)
      host.rootView = host.rootView
      host.layoutSubtreeIfNeeded()
    }

    #expect(list.scrollY > 0)
    let textView = try #require(list.file(at: 0)?.mainColumn.textView)
    let boxed = try #require(textView.steppedChange)
    let changeTop =
      try #require(list.top(ofFile: 0)) + AllChangesFileView.headerHeight
      + textView.geometry.top(ofRow: boxed.lowerBound)
    let context = CGFloat(DiffRowGeometry.contextRowsAboveAChange) * textView.geometry.rowHeight
    #expect(changeTop - context >= list.scrollY + AllChangesFileView.headerHeight - 1)
  }

  @Test func aComposerAboveTheClipScrollsInBelowTheStickyHeader() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    harness.model.select(worktree)
    let tab = try #require(harness.model.openAllChangesTab(in: worktree.id))
    let files = [Self.added("a.txt", rows: 200)]
    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: files.map(\.change),
      files: files,
    )
    let (list, host, window) = Self.shown(files, harness: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }
    let rowsTop = try #require(list.top(ofFile: 0)) + AllChangesFileView.headerHeight
    let geometry = try #require(list.file(at: 0)?.mainColumn.textView.geometry)
    list.scroll(toY: rowsTop + geometry.top(ofRow: 150))
    host.layoutSubtreeIfNeeded()

    harness.model.openReviewComposer(fromRow: 100, toRow: 100, ofSection: 0, side: nil, in: tab.id)
    host.rootView = AllChangesListRepresentable(
      model: harness.model,
      tab: tab,
      document: try #require(harness.model.allChangesDocument(of: tab.id)),
      theme: host.rootView.theme,
      font: host.rootView.font,
      find: host.rootView.find,
    )
    host.layoutSubtreeIfNeeded()

    let composer = try #require(harness.model.reviewComposers[tab.id])
    let column = try #require(list.file(at: 0)?.mainColumn)
    let span = try #require(column.reviewCards.span(of: .composer(composer.id)))
    #expect(rowsTop + span.lowerBound >= list.scrollY + AllChangesFileView.headerHeight - 1)
  }

  @Test func aFoldsLabelStartsWhereItsFilesCodeStarts() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let (list, _, window) = Self.shown(
      [Self.modified("a.txt", rows: 1_200)],
      harness: harness,
      tab: tab,
    )
    defer { withExtendedLifetime(window) {} }
    let file = try #require(list.file(at: 0))
    let column = file.mainColumn

    let codeInList = column.textClip.convert(NSPoint.zero, to: list)
    let codeXInList = file.diffView.spanningGapViews.convert(
      NSPoint(x: file.codeX, y: 0),
      to: list,
    )

    #expect(column.gutterWidth > 0)
    #expect(abs(codeXInList.x - codeInList.x) < 0.5)
  }
}
