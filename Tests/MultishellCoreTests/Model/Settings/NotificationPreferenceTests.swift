import Foundation
import Testing

@testable import MultishellCore

struct NotificationPreferenceTests {
  @Test func eachNotifiedStateIsAskedForOnItsOwnAndRunningNeverBanners() {
    let all = NotificationPreference(attention: true, failed: true, done: true)
    #expect(!all[.running], "a banner per tool call would be noise")
    #expect(!all[.idle])
    #expect(NotificationPreference.notifiableStates == [.attention, .failed, .done])

    for state in NotificationPreference.notifiableStates {
      var one = NotificationPreference.off
      one[state] = true
      #expect(one[state], "\(state)")
      for other in NotificationPreference.notifiableStates where other != state {
        #expect(!one[other], "\(state) does not turn on \(other)")
      }
    }
    #expect(NotificationPreference.notifiableStates.allSatisfy { !NotificationPreference.off[$0] })
  }

  @Test func aNotificationPreferenceThisBuildDoesNotKnowFallsBack() throws {
    let workspace = try decodeJSON(
      Workspace.self,
      #"{ "notifications": "whisper", "preferredAgentID": "future-agent", "projects": [ { "path": "file:///repos/demo/" } ] }"#
    )
    #expect(workspace.notifications == .off)
    #expect(workspace.preferredAgentID == "future-agent", "an unknown agent id is kept as text")
    #expect(workspace.projects.count == 1)

    let partial = try decodeJSON(
      NotificationPreference.self, #"{ "done": true, "whisper": true, "error": "yes" }"#)
    #expect(
      partial == NotificationPreference(done: true),
      "a state this build has not got is not one, and a bad value costs its own toggle")
  }
}
