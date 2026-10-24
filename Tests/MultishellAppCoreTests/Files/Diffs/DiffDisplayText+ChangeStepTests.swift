import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextChangeStepTests {
  private static let text = DiffDisplayText(
    [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "b"),
      DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "old c"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "new c"),
      DiffLine(kind: .context, oldNumber: 4, newNumber: 4, text: "d"),
      DiffLine(kind: .context, oldNumber: 5, newNumber: 5, text: "e"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 6, text: "f"),
      DiffLine(kind: .context, oldNumber: 6, newNumber: 7, text: "g"),
      DiffLine(kind: .context, oldNumber: 7, newNumber: 8, text: "h"),
      DiffLine(kind: .context, oldNumber: 8, newNumber: 9, text: "i"),
      DiffLine.padding,
      DiffLine(kind: .context, oldNumber: 10, newNumber: 10, text: "j"),
    ],
    marksStaging: true,
  )

  @Test func aStepDownFromASelectionInViewLandsOnTheNextRunOfChanges() {
    #expect(Self.text.startOfChange(.next, stepOriginRow: 2, shownRows: 0..<12) == 6)
  }

  @Test func aStepUpFromInsideARunLandsOnThatRunsFirstRow() {
    #expect(Self.text.startOfChange(.previous, stepOriginRow: 3, shownRows: 0..<12) == 2)
  }

  @Test func aSplitSidesPaddingRowsCountAsAChange() {
    #expect(Self.text.startOfChange(.next, stepOriginRow: 6, shownRows: 0..<12) == 10)
  }

  @Test func stepsStopAtTheLastChangeAndTheFirst() {
    #expect(Self.text.startOfChange(.next, stepOriginRow: 10, shownRows: 0..<12) == nil)
    #expect(Self.text.startOfChange(.previous, stepOriginRow: 2, shownRows: 0..<12) == nil)
  }

  @Test func onTheLastChangeOnlyAStepUpHasSomewhereToGo() {
    let steps = Self.text.changeSteps(stepOriginRow: 10, shownRows: 0..<12)

    #expect(!steps.allows(.next))
    #expect(steps.allows(.previous))
  }

  @Test func aChangeHoldingARowRunsFromItsFirstChangedRowToItsLast() {
    #expect(Self.text.change(containing: 3) == 2..<4)
    #expect(Self.text.change(containing: 2) == 2..<4)
    #expect(Self.text.change(containing: 4) == nil)
  }

  @Test func aSelectionOutOfViewStepsFromTheFirstRowInView() {
    #expect(Self.text.startOfChange(.next, stepOriginRow: 0, shownRows: 6..<9) == 6)
    #expect(Self.text.startOfChange(.previous, stepOriginRow: 0, shownRows: 6..<9) == 2)
  }

  @Test func withNoSelectionPlacedAStepDownLandsOnAChangeStartingInTheFirstRowInView() {
    let newFile = DiffDisplayText(
      [
        DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "a"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "b"),
      ],
      marksStaging: true,
    )

    #expect(newFile.startOfChange(.next, stepOriginRow: nil, shownRows: 0..<2) == 0)
  }

  @Test func theCaretATextOpensWithCountsAsNoSelectionUntilAChangeIsBoxed() {
    #expect(Self.text.stepOriginRow(caret: 0..<0, hasSteppedChange: false) == nil)
    #expect(Self.text.stepOriginRow(caret: 0..<0, hasSteppedChange: true) == 0)
    #expect(
      Self.text.stepOriginRow(
        caret: Self.text.rowStarts[3]..<Self.text.rowStarts[3],
        hasSteppedChange: false,
      ) == 3
    )
  }

  @Test func aFileWithNothingChangedHasNoChangeToStepTo() {
    let unchanged = DiffDisplayText(
      [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a")
      ],
      marksStaging: true,
    )

    #expect(unchanged.startOfChange(.next, stepOriginRow: 0, shownRows: 0..<1) == nil)
  }
}
