import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// The split-drift run the spike made, kept as the guard on the forced
/// geometry: plain TextKit 2 put offset-locked sides 787 to 3,435 rows apart.
@Suite @MainActor
struct SplitDiffDocumentViewTests {
  /// 200 lines, 100 removed for 100 added, then 200 more, the last `lastText`.
  private static func replacedBlock(lastText: String) -> FileTabRows {
    FileTabRows(
      lines: (0..<200).map { index in
        DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "a \(index)")
      }
        + (0..<100).map { index in
          DiffLine(kind: .removed, oldNumber: index + 201, newNumber: nil, text: "old \(index)")
        }
        + (0..<100).map { index in
          DiffLine(kind: .added, oldNumber: nil, newNumber: index + 201, text: "new \(index)")
        }
        + (0..<199).map { index in
          DiffLine(
            kind: .context,
            oldNumber: index + 301,
            newNumber: index + 301,
            text: "b \(index)",
          )
        }
        + [DiffLine(kind: .context, oldNumber: 500, newNumber: 500, text: lastText)]
    )
  }

  /// Each change removes three lines and adds one, so the sides pad unevenly.
  private static func lines(blocks: Int) -> [DiffLine] {
    var lines: [DiffLine] = []
    var old = 1
    var new = 1
    for block in 0..<blocks {
      for _ in 0..<4 {
        lines.append(DiffLine(kind: .context, oldNumber: old, newNumber: new, text: "same \(old)"))
        old += 1
        new += 1
      }
      for _ in 0..<3 {
        lines.append(
          DiffLine(kind: .removed, oldNumber: old, newNumber: nil, text: "gone \(block)")
        )
        old += 1
      }
      lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: new, text: "new \(block) 名前"))
      new += 1
    }
    return lines
  }

  @Test func bothSidesShowTheSameRowsAfterJumpsStartingAtTheEnd() throws {
    let split = SplitDiff(Self.lines(blocks: 1_536))
    let rows = split.onDisk.lines.count
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 900, height: 400)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    let geometry = view.onDisk.textView.geometry

    #expect(rows == 1_536 * 7, "four kept and three padded against one a block")
    for target in [rows - 1, 0, 5_000, 10_457, 1_234, 9_999, 3, 7_777, 4_321] {
      let range = view.committed.textView.displayText.range(ofRow: target)
      view.committed.textView.scrollRangeToVisible(NSRange(range))
      view.layoutSubtreeIfNeeded()
      let left = view.committed.textView.visibleRect.minY
      let right = view.onDisk.textView.visibleRect.minY
      #expect(
        left == right,
        "at row \(target) the sides are \(abs(left - right) / geometry.rowHeight) rows apart",
      )
      let rowRect = NSRect(
        x: 0,
        y: geometry.top(ofRow: target),
        width: 1,
        height: geometry.rowHeight,
      )
      #expect(
        view.onDisk.textView.visibleRect.intersects(rowRect),
        "row \(target) not shown on the right",
      )
    }
  }

  @Test func scrollingOneSideDownKeepsTheOtherSidesSidewaysScroll() throws {
    var lines = [
      DiffLine(
        kind: .removed,
        oldNumber: 1,
        newNumber: nil,
        text: String(repeating: "w", count: 400),
      )
    ]
    lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "short"))
    for row in 2...200 {
      lines.append(DiffLine(kind: .context, oldNumber: row, newNumber: row, text: "row \(row)"))
    }
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 600, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(SplitDiff(lines), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    view.committed.scroll(to: NSPoint(x: 1_500, y: 0))
    let sideways = view.committed.textView.visibleRect.minX

    view.onDisk.scroll(to: NSPoint(x: view.onDisk.textView.visibleRect.minX, y: 400))

    #expect(sideways > 1_000)
    #expect(view.committed.textView.visibleRect.minX == sideways)
    #expect(view.committed.textView.visibleRect.minY == view.onDisk.textView.visibleRect.minY)
  }

  @Test func withLegacyScrollBarsBothSidesStillEndOnTheSameRow() throws {
    var lines = [
      DiffLine(
        kind: .removed,
        oldNumber: 1,
        newNumber: nil,
        text: String(repeating: "w", count: 400),
      ),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "short"),
    ]
    for row in 2...200 {
      lines.append(DiffLine(kind: .context, oldNumber: row, newNumber: row, text: "row \(row)"))
    }
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 600, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    for side in [view.committed, view.onDisk] {
      for case let scroll as NSScrollView in side.subviews { scroll.scrollerStyle = .legacy }
    }
    view.show(SplitDiff(lines), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    view.onDisk.scroll(to: NSPoint(x: 0, y: 1_000_000))
    view.layoutSubtreeIfNeeded()

    #expect(view.committed.textView.visibleRect.minY == view.onDisk.textView.visibleRect.minY)
  }

  @Test func aStepToAChangeMovesBothSidesToIt() throws {
    let split = try #require(Self.replacedBlock(lastText: "end").split)
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    view.step(toChange: .next)

    #expect(view.onDisk.topRow == Double(200 - DiffRowGeometry.contextRowsAboveAChange))
    #expect(view.committed.scrollOrigin.y == view.onDisk.scrollOrigin.y)
  }

  @Test func aStepCountsFromTheLeftSideWhenTheLeftSideHasTheKeyboard() throws {
    let lines = (0..<60).map { row in
      row == 5 || row == 40
        ? DiffLine(kind: .removed, oldNumber: row + 1, newNumber: nil, text: "gone \(row)")
        : DiffLine(kind: .context, oldNumber: row + 1, newNumber: row + 1, text: "line \(row)")
    }
    let split = SplitDiff(lines)
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 1_200)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    window.makeFirstResponder(view.committed.textView)
    let clicked = split.committed.rowStarts[30]
    view.committed.textView.setSelectedRange(NSRange(location: clicked, length: 0))

    view.step(toChange: .next)

    #expect(
      view.committed.textView.selectedRange()
        == NSRange(location: split.committed.rowStarts[40], length: 0)
    )
  }

  @Test func aStepBoxesTheChangeOnBothSides() throws {
    let split = try #require(Self.replacedBlock(lastText: "end").split)
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    view.step(toChange: .next)

    #expect(view.onDisk.textView.steppedChange == 200..<300)
    #expect(view.committed.textView.steppedChange == 200..<300)
  }

  @Test func aChangeBoxedInUnifiedIsBoxedOnBothSidesOfTheSplitOpenedAfter() throws {
    let rows = Self.replacedBlock(lastText: "end")
    let anchor = try #require(rows.displayText.anchor(ofChangeAt: 200..<400))
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [ChangeAnchor?] = []
    view.onSteppedChangeAnchorChanged = { reported.append($0) }
    view.restoreSteppedChangeAnchor(anchor)
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }

    view.show(try #require(rows.split), theme: Theme.builtins[0])

    #expect(view.onDisk.textView.steppedChange == 200..<300)
    #expect(view.committed.textView.steppedChange == 200..<300)
    #expect(reported.last == anchor)
  }

  @Test func aSplitWhoseBoxedChangeIsGoneLetsGoOfIt() throws {
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [ChangeAnchor?] = []
    view.onSteppedChangeAnchorChanged = { reported.append($0) }
    view.restoreSteppedChangeAnchor(
      ChangeAnchor(
        headDigest: 0,
        headLineAbove: 5,
        headLineBelow: 6,
        textAbove: nil,
        lineText: "nowhere",
      )
    )
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }

    view.show(try #require(Self.replacedBlock(lastText: "end").split), theme: Theme.builtins[0])

    #expect(reported == [nil])
  }

  @Test func theArrowsFollowTheKeyboardToTheOtherSide() throws {
    let split = DiffDocumentFixture.split(rows: 400, removing: [50, 200])
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [ChangeSteps] = []
    view.onStepsCounted = { reported.append($0) }
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    view.step(toChange: .next)
    view.step(toChange: .next)
    let onTheLast = reported.last

    window.makeFirstResponder(view.committed.textView)
    view.committed.textView.setSelectedRange(
      NSRange(location: split.committed.rowStarts[199], length: 0)
    )

    #expect(onTheLast == ChangeSteps(hasNext: false, hasPrevious: true))
    #expect(reported.last == ChangeSteps(hasNext: true, hasPrevious: true))
  }

  @Test func theArrowsRecountWhenTheKeyboardMovesSidesWithoutASelectionChange() throws {
    let split = DiffDocumentFixture.split(rows: 400, removing: [50, 200])
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [ChangeSteps] = []
    view.onStepsCounted = { reported.append($0) }
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    view.committed.textView.setSelectedRange(
      NSRange(location: split.committed.rowStarts[199], length: 0)
    )
    window.makeFirstResponder(view.onDisk.textView)
    view.step(toChange: .next)
    view.step(toChange: .next)
    let onTheLast = reported.last

    window.makeFirstResponder(view.committed.textView)

    #expect(onTheLast == ChangeSteps(hasNext: false, hasPrevious: true))
    #expect(reported.last == ChangeSteps(hasNext: true, hasPrevious: true))
  }

  @Test func theKeyboardMovingBetweenOtherViewsLeavesTheArrowsUncounted() throws {
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let fields = [NSTextField(), NSTextField()]
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
    for (index, field) in fields.enumerated() {
      field.frame = NSRect(x: CGFloat(index) * 100, y: 320, width: 90, height: 20)
      content.addSubview(field)
    }
    content.addSubview(view)
    let window = OffscreenWindow.holding(content, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(DiffDocumentFixture.split(rows: 400, removing: [50]), theme: Theme.builtins[0])
    window.makeFirstResponder(fields[0])
    var counts = 0
    view.onStepsCounted = { _ in counts += 1 }

    window.makeFirstResponder(fields[1])
    window.makeFirstResponder(fields[0])

    #expect(counts == 0)
  }

  @Test func aRereadLetsGoOfABoxOnOneSideItCannotCarry() throws {
    let split = DiffDocumentFixture.split(rows: 400, removing: [50, 200])
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split, theme: Theme.builtins[0])
    view.committed.mirrorSteppedChange(50..<51)

    view.show(DiffDocumentFixture.split(rows: 400, removing: [200]), theme: Theme.builtins[0])

    #expect(view.committed.textView.steppedChange == nil)
  }

  @Test func aRereadThatDropsTheBoxRecountsTheArrows() throws {
    func split(revertingSeven: Bool) -> SplitDiff {
      var lines = [
        DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "1"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "1x"),
      ]
      lines += (2...6).map { (line: Int) in
        DiffLine(kind: .context, oldNumber: line, newNumber: line, text: "\(line)")
      }
      lines +=
        revertingSeven
        ? [DiffLine(kind: .context, oldNumber: 7, newNumber: 7, text: "7")]
        : [
          DiffLine(kind: .removed, oldNumber: 7, newNumber: nil, text: "7"),
          DiffLine(kind: .added, oldNumber: nil, newNumber: 7, text: "7x"),
        ]
      lines += (8...10).map { (line: Int) in
        DiffLine(kind: .context, oldNumber: line, newNumber: line, text: "\(line)")
      }
      return SplitDiff(lines)
    }
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [ChangeSteps] = []
    view.onStepsCounted = { reported.append($0) }
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(split(revertingSeven: false), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    window.makeFirstResponder(view.onDisk.textView)
    view.step(toChange: .next)
    view.step(toChange: .next)

    view.show(split(revertingSeven: true), theme: Theme.builtins[0])

    #expect(view.onDisk.textView.steppedChange == nil)
    #expect(reported.last?.allows(.next) == true)
  }

  @Test func aScrollLeftInUnifiedOpensSplitOnTheSameLine() throws {
    let rows = FileTabRows(
      lines: (0..<100).map { index in
        DiffLine(kind: .removed, oldNumber: index + 1, newNumber: nil, text: "old \(index)")
      }
        + (0..<100).map { index in
          DiffLine(kind: .added, oldNumber: nil, newNumber: index + 1, text: "new \(index)")
        }
        + (0..<400).map { index in
          DiffLine(
            kind: .context,
            oldNumber: index + 101,
            newNumber: index + 101,
            text: "line \(index)",
          )
        }
    )
    let unified = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    unified.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let unifiedWindow = OffscreenWindow.holding(unified, deferred: false)
    defer { withExtendedLifetime(unifiedWindow) {} }
    var saved: FileTabScroll?
    unified.onScrolledTo = { saved = $0 }
    unified.show(rows.displayText, theme: Theme.builtins[0])
    unified.layoutSubtreeIfNeeded()
    unified.scroll(to: NSPoint(x: 0, y: unified.textView.geometry.top(ofRow: 300)))

    let split = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    split.restore(try #require(saved))
    split.show(try #require(rows.split), theme: Theme.builtins[0])
    split.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let splitWindow = OffscreenWindow.holding(split, deferred: false)
    defer { withExtendedLifetime(splitWindow) {} }
    split.layoutSubtreeIfNeeded()

    let topRow = Int(split.onDisk.topRow.rounded())
    #expect(split.onDisk.textView.displayText.lines[topRow].newNumber == 201)
  }

  @Test func aSplitRestoredOnALineOnlyHEADHasShowsItOnBothSidesAndKeepsTheAnchor() throws {
    let rows = Self.replacedBlock(lastText: "b 199")
    let split = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [FileTabScroll] = []
    split.onScrolledTo = { reported.append($0) }
    split.restore(rows.displayText.scroll(atRow: 250, x: 0))
    split.show(try #require(rows.split), theme: Theme.builtins[0])
    #expect(reported.isEmpty)
    split.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(split, deferred: false)
    defer { withExtendedLifetime(window) {} }
    split.layoutSubtreeIfNeeded()

    let topRow = Int(split.committed.topRow.rounded())
    #expect(split.committed.textView.displayText.lines[topRow].oldNumber == 251)
    #expect(split.onDisk.scrollOrigin.y == split.committed.scrollOrigin.y)
    #expect(reported.isEmpty, "the model keeps the anchor it handed over")
  }

  @Test func aRereadThatLeavesTheTopLineInPlaceKeepsTheAnchorUnifiedHandedOver() throws {
    let before = Self.replacedBlock(lastText: "end")
    let after = Self.replacedBlock(lastText: "end edited far below")
    let anchor = before.displayText.scroll(atRow: 350, x: 0)
    let split = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [FileTabScroll] = []
    split.onScrolledTo = { reported.append($0) }
    split.restore(anchor)
    split.show(try #require(before.split), theme: Theme.builtins[0])
    split.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(split, deferred: false)
    defer { withExtendedLifetime(window) {} }
    split.layoutSubtreeIfNeeded()

    split.show(try #require(after.split), theme: Theme.builtins[0])
    split.layoutSubtreeIfNeeded()

    #expect(after.displayText.row(of: reported.last ?? anchor) == 350)
  }
}
