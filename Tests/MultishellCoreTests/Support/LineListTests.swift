import Testing

@testable import MultishellCore

@Suite
struct LineListTests {
  @Test func aLineListDropsBlanksAndCommentsAndTrimsTheRest() {
    #expect(LineList.entries(in: " a \n\n# no\nb\r\n") == ["a", "b"])
    #expect(LineList.entries(in: "   \n\n").isEmpty)
  }
}
