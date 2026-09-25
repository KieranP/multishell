import Foundation
import Testing

@testable import MultishellProcess

struct ProcessGroupTests {
  @Test func aGroupWhoseLeaderStartedAfterTheHangupIsAStrangers() throws {
    var hangup = timeval()
    gettimeofday(&hangup, nil)
    let stranger = Process()
    stranger.executableURL = URL(fileURLWithPath: "/bin/sleep")
    stranger.arguments = ["30"]
    try stranger.run()
    defer { stranger.terminate() }
    let group = stranger.processIdentifier

    #expect(!ProcessGroup.isStillOurs(hungUpAt: hangup, group: group))
    var later = timeval()
    gettimeofday(&later, nil)
    #expect(ProcessGroup.isStillOurs(hungUpAt: later, group: group))
    #expect(!ProcessGroup.isStillOurs(hungUpAt: later, group: 999_999))
  }
}
