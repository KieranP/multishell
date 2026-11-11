import Testing

@testable import MultishellCore

@Suite
struct StringPathUnderTests {
  @Test func aPathIsUnderAFolderOnlyPastAWholeComponent() {
    #expect("a/b".isPath(under: "a"))
    #expect("a/\u{0301}b".isPath(under: "a"))
    #expect(!"ab/c".isPath(under: "a"))
    #expect(!"a".isPath(under: "a"))
    #expect(!"x/a/b".isPath(under: "a"))
  }
}
