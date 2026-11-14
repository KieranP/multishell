import MultishellCore
import Testing

@testable import MultishellAppCore

struct DiffDisplayTextChangedRowsTests {
  private static let text = DiffDisplayText(
    [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "b"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 3, text: "c"),
      DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "d"),
    ],
    marksStaging: true,
  )

  @Test func nextFromNowhereIsTheFirstChangeAndPreviousTheLast() {
    #expect(Self.text.changedRow(.next, from: nil) == 1)
    #expect(Self.text.changedRow(.previous, from: nil) == 3)
  }

  @Test func eachWayStepsOverUnchangedRowsAndStopsAtTheEnds() {
    #expect(Self.text.changedRow(.next, from: 1) == 3)
    #expect(Self.text.changedRow(.previous, from: 3) == 1)
    #expect(Self.text.changedRow(.next, from: 3) == nil)
    #expect(Self.text.changedRow(.previous, from: 1) == nil)
  }
}
