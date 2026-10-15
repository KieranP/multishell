import Testing

@testable import MultishellAppCore

@Suite
struct FindMatchCountTests {
  @Test func aSelectedMatchReadsAsItsPlaceOfTheTotalAsChromeWritesIt() {
    let count = FindMatchCount(position: 1, total: 34)

    #expect(count.text == "1/34")
    #expect(count.spokenText == "match 1 of 34")
  }

  @Test func matchesBeforeAStepReadAsADashOfTheTotal() {
    let count = FindMatchCount(position: nil, total: 34)

    #expect(count.text == "-/34")
    #expect(count.spokenText == "34 matches")
  }

  @Test func noMatchesReadAsNoneOfNone() {
    let count = FindMatchCount(position: nil, total: 0)

    #expect(count.text == "0/0")
    #expect(count.spokenText == "0 matches")
  }
}
