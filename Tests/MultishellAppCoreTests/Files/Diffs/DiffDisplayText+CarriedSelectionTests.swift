import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextCarriedSelectionTests {
  private static func text(_ lines: [String]) -> DiffDisplayText {
    DiffDisplayText(
      lines.enumerated().map { index, line in
        DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: line)
      }
    )
  }

  private static func range(of word: String, in text: DiffDisplayText) -> Range<Int> {
    (text.string as NSString).range(of: word).integerRange
  }

  @Test func aSelectionFollowsItsLinesWhenLinesAreAddedAbove() {
    let before = Self.text(["one", "two", "three"])
    let after = Self.text(["zero", "one", "two", "three"])

    let carried = after.carriedSelection(Self.range(of: "wo\nthr", in: before), from: before)

    #expect(carried == Self.range(of: "wo\nthr", in: after))
  }

  @Test func aSelectionWhoseLinesAreGoneIsNotCarried() {
    let before = Self.text(["one", "two"])
    let after = Self.text(["one", "deux"])

    #expect(after.carriedSelection(Self.range(of: "tw", in: before), from: before) == nil)
  }

  @Test func aSelectionGoesToTheNearestCopyOfItsLines() {
    let before = Self.text(["x", "a", "x", "b", "x"])
    let after = Self.text(["x", "a", "x", "b", "x", "c", "x"])
    let lastButTwo = (before.string as NSString).range(of: "x", options: .backwards)

    let carried = after.carriedSelection(lastButTwo.integerRange, from: before)

    #expect(carried == after.rowStarts[4]..<(after.rowStarts[4] + 1))
  }

  @Test func aCaretFollowsItsLine() {
    let before = Self.text(["one", "two"])
    let after = Self.text(["new", "one", "two"])

    #expect(after.carriedSelection(5..<5, from: before) == 9..<9)
  }

  @Test func aSelectionLongerThanTheNewTextIsNotCarried() {
    let before = Self.text(["one", "two", "three"])
    let after = Self.text(["one"])

    #expect(after.carriedSelection(0..<before.string.utf16.count, from: before) == nil)
  }

  @Test func aSelectedNewlineCarriedOntoTheLastLineStopsAtTheEnd() {
    let before = Self.text(["a", "b"])
    let after = Self.text(["x", "a"])

    #expect(after.carriedSelection(0..<2, from: before) == 2..<3)
  }
}
