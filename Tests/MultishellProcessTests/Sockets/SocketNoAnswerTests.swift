import Testing

@testable import MultishellProcess

@Suite
struct SocketNoAnswerTests {
  @Test func aTimeoutUnderASecondIsSaidInItsFractionNotAsZero() {
    let failure = SocketNoAnswer(path: "/s", timeout: .milliseconds(300))

    #expect(failure.description == "no answer on /s within 0.3 seconds")
  }

  @Test func aWholeTimeoutIsSaidWithoutAFraction() {
    let failure = SocketNoAnswer(path: "/s", timeout: .seconds(30))

    #expect(failure.description == "no answer on /s within 30 seconds")
  }
}
