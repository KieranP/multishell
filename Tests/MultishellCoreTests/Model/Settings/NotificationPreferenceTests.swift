import Foundation
import Testing

@testable import MultishellCore

struct NotificationPreferenceTests {
  @Test func eachNotifiedStateIsAskedForOnItsOwnAndRunningNeverBanners() {
    let all = NotificationPreference(
      notifiesOnAttention: true,
      notifiesOnFailure: true,
      notifiesOnDone: true,
    )
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

  @Test func aNotificationPreferenceThisBuildDoesNotKnowFallsBackAndAnUnknownAgentStays() throws {
    let workspace = try decodeJSON(
      Workspace.self,
      #"{ "notifications": "whisper", "preferredAgentID": "future-agent", "projects": [ { "path": "file:///repos/demo/" } ] }"#,
    )
    #expect(workspace.notificationPreference == .off)
    #expect(workspace.preferredAgentID == "future-agent", "an unknown agent id is kept as text")
    #expect(workspace.projects.count == 1)

    let partial = try decodeJSON(
      NotificationPreference.self,
      #"{ "done": true, "whisper": true, "error": "yes" }"#,
    )
    #expect(
      partial == NotificationPreference(notifiesOnDone: true),
      "a state this build has not got is not one, and a bad value costs its own toggle",
    )
  }

  @Test func aWorkspaceFromBeforeTheNotificationTogglesKeepsWhatThePickerSaid() throws {
    let attention = try decodeJSON(Workspace.self, #"{ "notifications": "attentionOnly" }"#)
    #expect(attention.notificationPreference == NotificationPreference(notifiesOnAttention: true))
    let everything = try decodeJSON(Workspace.self, #"{ "notifications": "attentionAndDone" }"#)
    #expect(
      everything.notificationPreference
        == NotificationPreference(
          notifiesOnAttention: true,
          notifiesOnFailure: true,
          notifiesOnDone: true,
        ),
      "the picker's last rung was all three",
    )
    let off = try decodeJSON(Workspace.self, #"{ "notifications": "off" }"#)
    #expect(off.notificationPreference == .off)
  }
}
