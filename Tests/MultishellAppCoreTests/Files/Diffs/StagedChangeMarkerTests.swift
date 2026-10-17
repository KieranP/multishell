import Testing

@testable import MultishellAppCore

@Suite
struct StagedChangeMarkerTests {
  @Test func aChangeTheIndexHoldsIsStagedAndOneMadeSinceIsNot() {
    let working = [
      DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "a"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "A"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "b"),
      DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "c"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "new"),
    ]
    let staged = [
      DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "a"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "A"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "b"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "c"),
    ]

    let marked = StagedChangeMarker.marking(working, stagedIn: staged)

    #expect(marked.map(\.isStaged) == [true, true, false, false, false])
  }

  @Test func theSameTextAddedElsewhereIsNotTakenForTheStagedLine() {
    let working = [
      DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "x"),
      DiffLine(kind: .context, oldNumber: 1, newNumber: 2, text: "keep"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "x"),
    ]
    let staged = [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "keep"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "x"),
    ]

    #expect(
      StagedChangeMarker.marking(working, stagedIn: staged).map(\.isStaged) == [false, false, true]
    )
  }
}
