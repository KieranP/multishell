/// For tests, and for the model before a real notifier exists.
@MainActor
public final class NullNotifier: SessionNotifier {
  public var onActivate: (@MainActor (SessionStates.Key) -> Void)?
  public init() {}
  public func notify(title: String, body: String, about key: SessionStates.Key) {}
  public func withdraw(about key: SessionStates.Key) {}
  public func authorization() async -> NotificationAuthorization { .unavailable }
  public func requestAuthorization() async -> NotificationAuthorization { .unavailable }
}
