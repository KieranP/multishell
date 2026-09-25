import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct NotificationPolicyTests {
  private let everyState = NotificationPreference(attention: true, error: true, done: true)
  private let waitingOnly = NotificationPreference(attention: true)

  @Test func aPaneOnScreenIsNotWorthABanner() {
    #expect(
      !NotificationPolicy.shouldNotify(.attention, preference: everyState, isOnScreen: true))
    #expect(
      NotificationPolicy.shouldNotify(.attention, preference: everyState, isOnScreen: false),
      "on screen while the user is in another app is not seen")
    #expect(NotificationPolicy.shouldNotify(.done, preference: everyState, isOnScreen: false))
    #expect(!NotificationPolicy.shouldNotify(.done, preference: waitingOnly, isOnScreen: false))
    #expect(!NotificationPolicy.shouldNotify(.running, preference: everyState, isOnScreen: false))
  }

  /// A permission prompt reports twice, at the prompt and when the agent decides nobody has
  /// answered; the dot moves on both and the second carries the banner.
  @Test func aSilentReportMovesTheDotAndRaisesNoBanner() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isOnScreen: false, silent: true))
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isOnScreen: false),
      "the same report without the flag is the banner")
  }

  @Test func aShortCommandDoesNotEarnABannerButAnAgentOrALongOneDoes() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .done, preference: everyState, isOnScreen: false, duration: 0.2),
      "ls in a background tab")
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: everyState, isOnScreen: false, duration: 45))
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: everyState, isOnScreen: false, duration: nil),
      "an agent's Stop hook carries no duration")
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isOnScreen: false, duration: 0.1),
      "waiting is never short")
  }

  @Test func theBodyPrefersTheSourcesMessage() {
    #expect(NotificationPolicy.body(for: .attention, message: "Needs Bash") == "Needs Bash")
    #expect(NotificationPolicy.body(for: .attention, message: "") == "Waiting for your input.")
    #expect(NotificationPolicy.body(for: .done, message: nil) == "Finished.")
  }
}
