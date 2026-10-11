import Testing

@testable import MultishellCore

@Suite
struct ControlRequestTests {
  @Test func aRequestReadsBackAsTheOneEncoded() throws {
    let line = try ControlRequest.info.encodedLine()

    #expect(ControlRequest.parse(line) == .info)
  }

  @Test func aRequestFromANewerProtocolIsNoRequestHereEvenWhereItsCaseMatches() {
    #expect(ControlRequest.parse(#"{"v":2,"request":{"info":{}}}"#) == nil)
  }
}
