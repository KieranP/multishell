/// Posts a system notification about a session, and reports a click on it.
///
/// A port: each platform has its own notification centre, so the GUI
/// implements this and the model only decides what to say
/// (`NotificationPolicy`).
@MainActor
public protocol SessionNotifier: AnyObject {
  var onActivate: (@MainActor (SessionStates.Key) -> Void)? { get set }
  func notify(title: String, body: String, about key: SessionStates.Key)
}

/// For tests, and for the model before a real notifier exists.
@MainActor
public final class NullNotifier: SessionNotifier {
  public var onActivate: (@MainActor (SessionStates.Key) -> Void)?
  public init() {}
  public func notify(title: String, body: String, about key: SessionStates.Key) {}
}
