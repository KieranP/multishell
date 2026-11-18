import MultishellCore
import Testing

@testable import MultishellAppCore

struct AllChangesHeldLinesTests {
  private static func context(_ number: Int) -> DiffLine {
    DiffLine(kind: .context, oldNumber: number, newNumber: number + 10, text: "")
  }

  @Test func overlappingAndTouchingSpansHoldEveryLineTheyCoverOnTheirOwnSide() {
    let held = AllChangesHeldLines([
      AllChangesLineSpan(side: .onDisk, lines: 20...22),
      AllChangesLineSpan(side: .onDisk, lines: 23...25),
      AllChangesLineSpan(side: .onDisk, lines: 21...24),
      AllChangesLineSpan(side: .committed, lines: 40...40),
    ])

    let heldNumbers = (0...50).filter { held.holds(Self.context($0)) }

    #expect(heldNumbers == [10, 11, 12, 13, 14, 15, 40])
  }
}
