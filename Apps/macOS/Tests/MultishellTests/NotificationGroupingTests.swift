import Foundation
import MultishellAppCore
import Testing

@testable import Multishell

/// One banner per pane: the identifier a request carries is what makes a
/// second report about a terminal replace the first rather than stack beside
/// it, so it has to be stable for the pane and distinct across panes.
struct NotificationGroupingTests {
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

  /// A worktree's id is a path and a session's a UUID, so the two cannot
  /// collide today; the prefix is what keeps that from being the reason,
  /// since a worktree at a path spelled like a UUID would otherwise take a
  /// pane's banner down with it.
  @Test func aWorktreeAndASessionNeverShareAnIdentifier() {
    let id = UUID()
    #expect(
      UserNotificationNotifier.identifier(for: .session(id))
        != UserNotificationNotifier.identifier(for: .worktree(id.uuidString)))
  }
}
