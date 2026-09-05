import Foundation

/// Which reported states post a system notification for a tab the user is
/// not looking at. Running never does; a prompt about every tool call would
/// be noise.
public enum NotificationPreference: String, Codable, Hashable, Sendable, CaseIterable {
  case off
  case attentionOnly
  case attentionAndDone

  /// Off until asked for: a banner about a tab is welcome once expected and
  /// startling before, and turning it on is where the permission prompt
  /// belongs.
  public static let `default` = NotificationPreference.off

  public var displayName: String {
    switch self {
    case .off: "Off"
    case .attentionOnly: "Waiting for input only"
    case .attentionAndDone: "Waiting for input, done and failed"
    }
  }

  public func notifies(_ state: SessionState) -> Bool {
    switch (self, state) {
    case (.off, _), (_, .running), (_, .idle): false
    case (.attentionOnly, .attention): true
    case (.attentionOnly, .done), (.attentionOnly, .error): false
    case (.attentionAndDone, .attention), (.attentionAndDone, .done), (.attentionAndDone, .error):
      true
    }
  }
}
