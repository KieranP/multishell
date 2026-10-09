import Testing

@testable import MultishellProcess

@Suite
struct ProcessArgumentsTests {
  private func buffer(argc: Int32, _ words: [String]) -> ArraySlice<UInt8> {
    var bytes = withUnsafeBytes(of: argc) { Array($0) }
    bytes += Array("/bin/sh".utf8) + [0, 0, 0]
    for word in words { bytes += Array(word.utf8) + [0] }
    return bytes[...]
  }

  @Test func theArgumentsStopAtTheirCountAndKeepAnEmptyOne() throws {
    let parsed = try #require(
      ProcessArguments(sysctlBuffer: buffer(argc: 3, ["sh", "", "-l", "HOME=/u"]))
    )
    #expect(parsed.arguments == ["sh", "", "-l"])
  }

  @Test func aBufferWithNoRoomForACountReadsAsNothing() {
    #expect(ProcessArguments(sysctlBuffer: [1, 0][...]) == nil)
  }
}
