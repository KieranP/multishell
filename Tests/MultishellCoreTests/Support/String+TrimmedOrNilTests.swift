import Testing

@testable import MultishellCore

@Suite
struct StringTrimmedOrNilTests {
  @Test func surroundingSpacesAreTrimmedAndInnerOnesKept() {
    #expect("  my name\t".trimmedOrNil == "my name")
  }

  @Test func anEmptyOrBlankStringIsNil() {
    #expect("".trimmedOrNil == nil)
    #expect(" \t ".trimmedOrNil == nil)
  }
}
