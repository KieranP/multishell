/// What the platform's notification centre has been told about this app. A
/// refusal is worth showing, the toggles doing nothing until it is lifted.
public enum NotificationAuthorization: Hashable, Sendable {
  /// Nobody has been asked yet, so turning a state on will ask.
  case notAsked
  case allowed
  case refused
  /// There is no notification centre to ask: a bare binary outside an app
  /// bundle, or a platform without one.
  case unavailable
}
