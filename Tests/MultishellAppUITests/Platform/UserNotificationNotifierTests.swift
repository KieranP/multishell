import Foundation
import MultishellAppCore
import Testing

@testable import MultishellAppUI

/// A request's identifier makes a second report about a pane replace the first banner
/// rather than stack beside it, so it is stable per pane and distinct across panes.
struct UserNotificationNotifierTests {
  @Test func aKeyAlwaysMakesTheSameIdentifierAndNoTwoKeysShareOne() {
    let first = UUID()
    let second = UUID()
    #expect(
      UserNotificationNotifier.identifier(for: .session(first))
        == UserNotificationNotifier.identifier(for: .session(first)))
    #expect(
      UserNotificationNotifier.identifier(for: .session(first))
        != UserNotificationNotifier.identifier(for: .session(second)))
    #expect(
      UserNotificationNotifier.identifier(for: .worktree("/w/repo"))
        != UserNotificationNotifier.identifier(for: .worktree("/w/other")))
  }

  /// The prefix, not path-versus-UUID, keeps these apart: a worktree at a path spelled
  /// like a UUID would otherwise take a pane's banner down with it.
  @Test func aWorktreeAndASessionNeverShareAnIdentifier() {
    let id = UUID()
    #expect(
      UserNotificationNotifier.identifier(for: .session(id))
        != UserNotificationNotifier.identifier(for: .worktree(id.uuidString)))
  }
}
