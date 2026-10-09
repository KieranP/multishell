import Foundation
import Testing

@testable import MultishellAppCore

/// A request's identifier makes a second report about a pane replace the first banner
/// rather than stack beside it, so it is stable per pane and distinct across panes.
struct SessionStatesKeyNotificationIdentifierTests {
  @Test func aKeyAlwaysMakesTheSameIdentifierAndNoTwoKeysShareOne() {
    let first = UUID()
    let second = UUID()
    #expect(
      SessionStates.Key.session(first).notificationIdentifier
        == SessionStates.Key.session(first).notificationIdentifier
    )
    #expect(
      SessionStates.Key.session(first).notificationIdentifier
        != SessionStates.Key.session(second).notificationIdentifier
    )
    #expect(
      SessionStates.Key.worktree("/w/repo").notificationIdentifier
        != SessionStates.Key.worktree("/w/other").notificationIdentifier
    )
  }

  /// The prefix, not path-versus-UUID, keeps these apart: a worktree at a path spelled
  /// like a UUID would otherwise take a pane's banner down with it.
  @Test func aWorktreeAndASessionNeverShareAnIdentifier() {
    let id = UUID()
    #expect(
      SessionStates.Key.session(id).notificationIdentifier
        != SessionStates.Key.worktree(id.uuidString).notificationIdentifier
    )
  }

  @Test func aBannersKeyIsReadBackOffItsIdentifier() {
    let keys: [SessionStates.Key] = [.session(UUID()), .worktree("/w/repo")]
    for key in keys {
      #expect(SessionStates.Key(notificationIdentifier: key.notificationIdentifier) == key)
    }
    #expect(SessionStates.Key(notificationIdentifier: "session:not-a-uuid") == nil)
    #expect(SessionStates.Key(notificationIdentifier: "other") == nil)
  }
}
