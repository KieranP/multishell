import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlNotificationsTests {
  @Test func theBannersPostedAreListedOldestFirstAndOnlyAStandingOneIsUp() async throws {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()
    let pane = tab.focusedSessionID
    harness.messageSource.send(
      SessionStateReport(state: .attention, sessionID: pane, message: "Hi")
    )
    harness.messageSource.send(SessionStateReport(state: .running, sessionID: pane))
    harness.messageSource.send(SessionStateReport(state: .done, sessionID: pane))

    let reply = try #require(await harness.messageSource.ask(.debugNotifications))

    let banners = try #require(reply.outputFields["banners"] as? [[String: Any]])
    #expect(banners.count == harness.notifier.posted.count)
    #expect(banners.first?["body"] as? String == "Hi")
    #expect(banners.allSatisfy { $0["pane"] as? String == pane.uuidString })
    #expect(banners.compactMap { $0["isStanding"] as? Bool } == [false, true])
  }
}
