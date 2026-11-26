import Testing

@testable import MultishellAppCore

@Suite
struct ArrayOccurrencesTests {
  @Test func overlappingOccurrencesAreEachFound() {
    #expect(Array("aaaa").startsOfOccurrences(of: Array("aa"), by: ==) == [0, 1, 2])
  }

  @Test func aPatternWhosePrefixRepeatsIsFoundAfterAFalseStart() {
    #expect(Array("abababc").startsOfOccurrences(of: Array("ababc"), by: ==) == [2])
  }

  @Test func anEmptyOrLongerPatternIsFoundNowhere() {
    #expect(Array("ab").startsOfOccurrences(of: [], by: ==).isEmpty)
    #expect(Array("ab").startsOfOccurrences(of: Array("abc"), by: ==).isEmpty)
  }
}
