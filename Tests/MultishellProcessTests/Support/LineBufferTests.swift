import Testing

@testable import MultishellProcess

@Suite
struct LineBufferTests {
  @Test func eachCompleteLineComesOutOnceWithoutItsNewline() {
    var buffer = LineBuffer()
    #expect(buffer.append(Array("one\ntwo\n".utf8)) == ["one", "two"])
    #expect(buffer.append(Array("three\n".utf8)) == ["three"])
    #expect(buffer.pendingByteCount == 0)
  }

  @Test func aLineSplitAcrossAppendsComesOutWhole() {
    var buffer = LineBuffer()
    #expect(buffer.append(Array("fo".utf8)).isEmpty)
    #expect(buffer.pendingByteCount == 2)
    #expect(buffer.append(Array("ur\nfi".utf8)) == ["four"])
    #expect(buffer.append(Array("ve\n".utf8)) == ["five"])
  }

  @Test func whatFollowsTheLastNewlineIsTakenOnlyWhenAskedFor() {
    var buffer = LineBuffer()
    _ = buffer.append(Array("done\npartial".utf8))
    #expect(buffer.takeRest() == "partial")
    #expect(buffer.takeRest() == nil)
    #expect(buffer.pendingByteCount == 0)
  }

  @Test func anEmptyLineIsStillALine() {
    var buffer = LineBuffer()
    #expect(buffer.append(Array("\n\nx\n".utf8)) == ["", "", "x"])
  }
}
