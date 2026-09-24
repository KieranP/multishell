import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct NotificationPolicyTests {
  private let everyState = NotificationPreference(attention: true, error: true, done: true)
  private let waitingOnly = NotificationPreference(attention: true)

  @Test func aTabTheUserHasSeenIsNotWorthABanner() {
    #expect(
      !NotificationPolicy.shouldNotify(.attention, preference: everyState, isSeen: true))
    #expect(
      NotificationPolicy.shouldNotify(.attention, preference: everyState, isSeen: false),
      "on screen while the user is in another app is not seen")
    #expect(NotificationPolicy.shouldNotify(.done, preference: everyState, isSeen: false))
    #expect(!NotificationPolicy.shouldNotify(.done, preference: waitingOnly, isSeen: false))
    #expect(!NotificationPolicy.shouldNotify(.running, preference: everyState, isSeen: false))
  }

  /// A permission prompt reports twice, at the prompt and when the agent decides nobody has
  /// answered; the dot moves on both and the second carries the banner.
  @Test func aSilentReportMovesTheDotAndRaisesNoBanner() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isSeen: false, silent: true))
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isSeen: false),
      "the same report without the flag is the banner")
  }

  @Test func aShortCommandDoesNotEarnABannerButAnAgentOrALongOneDoes() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .done, preference: everyState, isSeen: false, duration: 0.2),
      "ls in a background tab")
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: everyState, isSeen: false, duration: 45))
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: everyState, isSeen: false, duration: nil),
      "an agent's Stop hook carries no duration")
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isSeen: false, duration: 0.1),
      "waiting is never short")
  }

  @Test func theBodyPrefersTheSourcesMessage() {
    #expect(NotificationPolicy.body(for: .attention, message: "Needs Bash") == "Needs Bash")
    #expect(NotificationPolicy.body(for: .attention, message: "") == "Waiting for your input.")
    #expect(NotificationPolicy.body(for: .done, message: nil) == "Finished.")
  }
}

@Suite
struct NotificationTitleTests {
  @Test func theTitlePutsTheSubjectBeforeWhereItIs() {
    #expect(
      NotificationPolicy.title(subject: "claude", project: "acme", worktree: "feat")
        == "claude · acme › feat")
  }
}
