import Testing

@testable import MultishellAppCore

@Suite
struct HandoffLogTailTests {
  @Test func carriageReturnsAreDroppedWithTheBlankLinesAtTheEnd() {
    let tail = HandoffLogTail.lines(of: "error: boom\r\n  at App.swift:12\r\n\r\n")

    #expect(tail.lines == ["error: boom", "  at App.swift:12"])
    #expect(tail.cutCount == 0)
  }

  @Test func aProgressBarsBareCarriageReturnsStayInsideItsOneLine() {
    let tail = HandoffLogTail.lines(of: "10%\r50%\r100%\nerror: boom")

    #expect(tail.lines == ["10%\r50%\r100%", "error: boom"])
    #expect(tail.cutCount == 0)
  }
}
