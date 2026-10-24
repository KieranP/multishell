import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextFileTabTests {
  private static let added = DiffLine(
    kind: .added,
    oldNumber: nil,
    newNumber: 40,
    text: "let a = 1",
  )
  private static let removed = DiffLine(kind: .removed, oldNumber: 21, newNumber: nil, text: "b")

  @Test func aChangedLineSaysWhetherItIsStagedWhereTheRowsMarkIt() {
    #expect(
      AccessibilityText.changedLine(Self.added, marksStaging: true)
        == "Added, unstaged, line 40: let a = 1"
    )
    #expect(
      AccessibilityText.changedLine(Self.removed, marksStaging: true)
        == "Removed, unstaged, was line 21: b"
    )
  }

  @Test func aChangedLineSaysNothingOfStagingWhereTheRowsCannotTell() {
    #expect(
      AccessibilityText.changedLine(Self.added, marksStaging: false) == "Added, line 40: let a = 1"
    )
    #expect(
      AccessibilityText.changedLine(Self.removed, marksStaging: false) == "Removed, was line 21: b"
    )
  }
}
