import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextChangeAnchorTests {
  private static let rows = FileTabRows(
    lines: [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "old b"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "new b"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "c"),
      DiffLine(kind: .removed, oldNumber: 4, newNumber: nil, text: "gone d"),
      DiffLine(kind: .context, oldNumber: 5, newNumber: 4, text: "e"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 5, text: "f"),
    ]
  )

  /// `HEAD` has lines 1 to 6; the file adds `added` lines after line 2 and "y"
  /// after line 4.
  private static func additions(adding added: Int) -> DiffDisplayText {
    var lines = [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "1"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "2"),
    ]
    lines += (0..<added).map { index in
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3 + index, text: "x\(index)")
    }
    lines += [
      DiffLine(kind: .context, oldNumber: 3, newNumber: 3 + added, text: "3"),
      DiffLine(kind: .context, oldNumber: 4, newNumber: 4 + added, text: "4"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 5 + added, text: "y"),
      DiffLine(kind: .context, oldNumber: 5, newNumber: 6 + added, text: "5"),
    ]
    return DiffDisplayText(lines)
  }

  /// `HEAD` has lines 1 to 8; the file adds `first` after line 2 and "}" after
  /// line 6.
  private static func braces(first: String?) -> DiffDisplayText {
    var lines = [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "func a() {"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "  a()"),
    ]
    var new = 3
    if let first {
      lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: new, text: first))
      new += 1
    }
    for old in 3...6 {
      lines.append(DiffLine(kind: .context, oldNumber: old, newNumber: new, text: "line \(old)"))
      new += 1
    }
    lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: new, text: "}"))
    lines.append(DiffLine(kind: .context, oldNumber: 7, newNumber: new + 1, text: "line 7"))
    return DiffDisplayText(lines)
  }

  @Test func aChangeIsFoundAgainByItsAnchor() throws {
    let unified = Self.rows.displayText

    let anchor = try #require(unified.anchor(ofChangeAt: 1..<3))

    #expect(unified.change(at: anchor) == 1..<3)
  }

  @Test func anAdditionIsFoundAgainThoughLinesWereAddedAboveIt() throws {
    let before = Self.additions(adding: 1)
    let after = Self.additions(adding: 3)
    let anchor = try #require(before.anchor(ofChangeAt: 5..<6))

    #expect(after.change(at: anchor) == 7..<8)
  }

  @Test func aChangeIsFoundAgainOnceTheChangesAboveItAreCommitted() throws {
    let before = Self.additions(adding: 2)
    let committed = DiffDisplayText([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "1"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "2"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "x0"),
      DiffLine(kind: .context, oldNumber: 4, newNumber: 4, text: "x1"),
      DiffLine(kind: .context, oldNumber: 5, newNumber: 5, text: "3"),
      DiffLine(kind: .context, oldNumber: 6, newNumber: 6, text: "4"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 7, text: "y"),
      DiffLine(kind: .context, oldNumber: 7, newNumber: 8, text: "5"),
    ])
    let anchor = try #require(before.anchor(ofChangeAt: 6..<7))

    #expect(committed.change(at: anchor) == 6..<7)
  }

  @Test func aChangeGrownUpwardOverTheLineAboveItKeepsItsAnchor() throws {
    let before = Self.additions(adding: 1)
    let grown = DiffDisplayText([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "1"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "2"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "x0"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 4, text: "3"),
      DiffLine(kind: .removed, oldNumber: 4, newNumber: nil, text: "4"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 5, text: "4 edited"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 6, text: "y"),
      DiffLine(kind: .context, oldNumber: 5, newNumber: 7, text: "5"),
    ])
    let anchor = try #require(before.anchor(ofChangeAt: 5..<6))

    #expect(grown.change(at: anchor) == 4..<7)
  }

  @Test func aChangeWhoseFirstLineWasEditedIsFoundByItsPlace() throws {
    let before = Self.additions(adding: 1)
    let edited = DiffDisplayText(
      before.lines.map { line in
        line.text == "y"
          ? DiffLine(kind: .added, oldNumber: nil, newNumber: line.newNumber, text: "y edited")
          : line
      }
    )
    let anchor = try #require(before.anchor(ofChangeAt: 5..<6))

    #expect(edited.change(at: anchor) == 5..<6)
  }

  @Test func aChangeWhoseCommonFirstLineWasEditedStaysBoxedInPlace() throws {
    let anchor = try #require(Self.braces(first: "}").anchor(ofChangeAt: 2..<3))

    #expect(Self.braces(first: "};").change(at: anchor) == 2..<3)
  }

  @Test func aRevertedChangeIsNotFoundInAnotherChangeOfTheSameText() throws {
    let anchor = try #require(Self.braces(first: "}").anchor(ofChangeAt: 2..<3))

    #expect(Self.braces(first: nil).change(at: anchor) == nil)
  }

  @Test func aChangeWhoseFirstLineIsRevertedKeepsItsAnchor() throws {
    func text(revertingThree: Bool) -> DiffDisplayText {
      var lines = [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "1"),
        DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "2"),
      ]
      lines +=
        revertingThree
        ? [DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "3")]
        : [DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "3")]
      lines.append(DiffLine(kind: .removed, oldNumber: 4, newNumber: nil, text: "4"))
      if !revertingThree {
        lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "3x"))
      }
      lines += [
        DiffLine(kind: .added, oldNumber: nil, newNumber: 4, text: "4x"),
        DiffLine(kind: .context, oldNumber: 5, newNumber: 5, text: "5"),
      ]
      return DiffDisplayText(lines)
    }
    let anchor = try #require(text(revertingThree: false).anchor(ofChangeAt: 2..<6))

    #expect(text(revertingThree: true).change(at: anchor) == 3..<5)
  }

  @Test func aChangeWhoseOnlyReplacedLineIsRevertedKeepsTheLinesAddedAfterIt() throws {
    func text(revertingFive: Bool) -> DiffDisplayText {
      var lines = (1...4).map { (line: Int) in
        DiffLine(kind: .context, oldNumber: line, newNumber: line, text: "\(line)")
      }
      lines +=
        revertingFive
        ? [DiffLine(kind: .context, oldNumber: 5, newNumber: 5, text: "5")]
        : [
          DiffLine(kind: .removed, oldNumber: 5, newNumber: nil, text: "5"),
          DiffLine(kind: .added, oldNumber: nil, newNumber: 5, text: "5x"),
        ]
      lines += [
        DiffLine(kind: .added, oldNumber: nil, newNumber: 6, text: "5y"),
        DiffLine(kind: .context, oldNumber: 6, newNumber: 7, text: "6"),
      ]
      return DiffDisplayText(lines)
    }
    let anchor = try #require(text(revertingFive: false).anchor(ofChangeAt: 4..<7))

    #expect(text(revertingFive: true).change(at: anchor) == 5..<6)
  }

  @Test func aChangeStillReplacingHEADLinesWinsOverALineAddedAboveIt() throws {
    let boxed = DiffDisplayText(
      (1...4).map(DiffLine.unchanged) + DiffLine.replaced(5...7) + [.unchanged(8)]
    )
    let edited = DiffDisplayText(
      (1...4).map(DiffLine.unchanged)
        + [DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "new")]
        + [.unchanged(5)] + DiffLine.replaced(6...7) + [.unchanged(8)]
    )
    let anchor = try #require(boxed.anchor(ofChangeAt: 4..<10))

    #expect(edited.change(at: anchor) == 6..<10)
  }

  @Test func atTheEndOfTheFileAChangeStillReplacingHEADLinesWinsOverLinesAppended() throws {
    let boxed = DiffDisplayText((1...4).map(DiffLine.unchanged) + DiffLine.replaced(5...7))
    let edited = DiffDisplayText(
      (1...4).map(DiffLine.unchanged) + DiffLine.replaced(5...6) + [.unchanged(7)]
        + [DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "tail")]
    )
    let anchor = try #require(boxed.anchor(ofChangeAt: 4..<10))

    #expect(edited.change(at: anchor) == 4..<8)
  }

  @Test func aCommitRenumberingHEADUnderABlankLineFindsTheBoxByTextNotByNumber() throws {
    func text(committingAbove committed: Int) -> DiffDisplayText {
      var lines = DiffLine.committedAbove(committed)
      for old in 1...20 {
        let head = old + committed
        lines.append(
          DiffLine(
            kind: .context,
            oldNumber: head,
            newNumber: nil,
            text: old == 5 || old == 10 ? "" : "line \(old)",
          )
        )
        if old == 5 {
          lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "other"))
        }
        if old == 10 {
          lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "boxed"))
        }
      }
      return DiffDisplayText(lines)
    }
    let anchor = try #require(text(committingAbove: 0).anchor(ofChangeAt: 11..<12))

    #expect(text(committingAbove: 5).change(at: anchor) == 16..<17)
  }

  @Test func aChangeOpeningWithABraceIsFoundAfterACommitByItsFirstWordyLine() throws {
    func text(committingAbove committed: Int) -> DiffDisplayText {
      var lines = DiffLine.committedAbove(committed)
      lines += (1...4).map { (old: Int) in
        DiffLine(kind: .context, oldNumber: old + committed, newNumber: nil, text: "line \(old)")
      }
      lines += [
        DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "}"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "return foo(bar)"),
        DiffLine(kind: .context, oldNumber: 5 + committed, newNumber: nil, text: "line 5"),
      ]
      return DiffDisplayText(lines)
    }
    let anchor = try #require(text(committingAbove: 0).anchor(ofChangeAt: 4..<6))

    #expect(text(committingAbove: 3).change(at: anchor) == 7..<9)
  }

  @Test func aRevertedChangeIsNotFoundInAnEditBesideIt() throws {
    func text(_ changed: [DiffLine]) -> DiffDisplayText {
      DiffDisplayText(
        (1...6).map { (line: Int) in
          DiffLine(kind: .context, oldNumber: line, newNumber: line, text: "\(line)")
        }
          + changed
          + [DiffLine(kind: .context, oldNumber: 9, newNumber: 9, text: "9")]
      )
    }
    let boxed = text([
      DiffLine(kind: .removed, oldNumber: 7, newNumber: nil, text: "7"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 7, text: "7x"),
      DiffLine(kind: .context, oldNumber: 8, newNumber: 8, text: "8"),
    ])
    let reverted = text([
      DiffLine(kind: .context, oldNumber: 7, newNumber: 7, text: "7"),
      DiffLine(kind: .removed, oldNumber: 8, newNumber: nil, text: "8"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 8, text: "8x"),
    ])
    let anchor = try #require(boxed.anchor(ofChangeAt: 6..<8))

    #expect(reverted.change(at: anchor) == nil)
  }

  @Test func aBlankLineUnderABraceDoesNotSendTheBoxToAnotherOne() throws {
    func text(keepingFirst: Bool) -> DiffDisplayText {
      var lines = [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "func a() {"),
        DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "}"),
      ]
      var new = 3
      if keepingFirst {
        lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: new, text: ""))
        new += 1
      }
      for old in 3...60 {
        lines.append(DiffLine(kind: .context, oldNumber: old, newNumber: new, text: "line \(old)"))
        new += 1
      }
      lines.append(DiffLine(kind: .context, oldNumber: 61, newNumber: new, text: "}"))
      lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: new + 1, text: ""))
      lines.append(DiffLine(kind: .context, oldNumber: 62, newNumber: new + 2, text: "line 62"))
      return DiffDisplayText(lines)
    }
    let anchor = try #require(text(keepingFirst: true).anchor(ofChangeAt: 2..<3))

    #expect(text(keepingFirst: false).change(at: anchor) == nil)
  }

  @Test func aPartialCommitAboveKeepsTheBoxOffTheChangeNowOnItsOldLines() throws {
    func context(_ text: String, _ old: Int) -> DiffLine {
      DiffLine(kind: .context, oldNumber: old, newNumber: nil, text: text)
    }
    func edit(_ text: String, _ old: Int) -> [DiffLine] {
      [
        DiffLine(kind: .removed, oldNumber: old, newNumber: nil, text: text),
        DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: text + "x"),
      ]
    }
    let before = DiffDisplayText(
      [context("L1", 1), context("L2", 2)]
        + [DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "a1")]
        + [DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "a2")]
        + [context("L3", 3), context("L4", 4)] + edit("L5", 5) + [context("L6", 6)]
        + edit("L7", 7) + [context("L8", 8)]
    )
    let committed = DiffDisplayText(
      [context("L1", 1), context("L2", 2), context("a1", 3), context("a2", 4)]
        + [context("L3", 5), context("L4", 6)] + edit("L5", 7) + [context("L6", 8)]
        + edit("L7", 9) + [context("L8", 10)]
    )
    let anchor = try #require(before.anchor(ofChangeAt: 9..<11))

    #expect(committed.change(at: anchor) == 9..<11)
  }

  @Test func aDeletedChangeIsNotFoundInALookalikeWhenNothingWasCommitted() throws {
    func text(keepingFirst: Bool) -> DiffDisplayText {
      var lines: [DiffLine] = []
      for old in 1...40 {
        let isLet = old == 3 || old == 33
        lines.append(
          DiffLine(
            kind: .context,
            oldNumber: old,
            newNumber: nil,
            text: isLet ? "  let x = compute()" : "line \(old)",
          )
        )
        if isLet, old == 33 || keepingFirst {
          lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "  print(x)"))
        }
      }
      return DiffDisplayText(lines)
    }
    let anchor = try #require(text(keepingFirst: true).anchor(ofChangeAt: 3..<4))

    #expect(text(keepingFirst: false).change(at: anchor) == nil)
  }

  @Test func aChangeNoLongerThereFindsNone() throws {
    let anchor = try #require(Self.additions(adding: 1).anchor(ofChangeAt: 5..<6))
    let reverted = DiffDisplayText(
      Self.additions(adding: 1).lines.filter { $0.text != "y" }
    )

    #expect(reverted.change(at: anchor) == nil)
  }
}
