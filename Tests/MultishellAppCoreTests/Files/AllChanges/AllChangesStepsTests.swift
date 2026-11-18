import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AllChangesStepsTests {
  private static let steps = AllChangesSteps([
    .init(stop: .init(section: 0, row: 2), top: 40),
    .init(stop: .init(section: 1, row: 0), top: 120),
    .init(stop: .init(section: 1, row: 9), top: 300),
  ])

  @Test func aStepFromAFilesLastChangeLandsOnTheNextFilesFirst() {
    #expect(Self.steps.stop(.next, from: 40, isBoxed: true) == .init(section: 1, row: 0))
    #expect(Self.steps.stop(.previous, from: 120, isBoxed: true) == .init(section: 0, row: 2))
  }

  @Test func aChangeAtTheClipsTopIsTheFirstStepWhenNothingIsBoxed() {
    #expect(Self.steps.stop(.next, from: 120, isBoxed: false) == .init(section: 1, row: 0))
  }

  @Test func theArrowsSayWhichWaysAStepCanGo() {
    #expect(
      Self.steps.changeSteps(from: 300, isBoxed: true)
        == ChangeSteps(hasNext: false, hasPrevious: true)
    )
    #expect(
      Self.steps.changeSteps(from: 0, isBoxed: false)
        == ChangeSteps(hasNext: true, hasPrevious: false)
    )
  }
}
