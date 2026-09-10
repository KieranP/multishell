import AppKit
import MultishellAppCore
import MultishellCore
@preconcurrency import UserNotifications

/// `SessionNotifier` on `UNUserNotificationCenter`, which needs a bundle: a
/// bare binary from `swift run` has none, and asking the center there
/// crashes, so this does nothing outside an app bundle. Authorization is
/// asked for when a notification is first turned on in Settings, and again
/// here if a report arrives before anyone has been asked.
@MainActor
final class UserNotificationNotifier: NSObject, SessionNotifier {
  var onActivate: (@MainActor (SessionStates.Key) -> Void)?

  private let center: UNUserNotificationCenter?
  /// The last answer, so a settled permission costs no hop before posting.
  private var known = NotificationAuthorization.notAsked

  override init() {
    center = Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    super.init()
    center?.delegate = self
  }

  func notify(title: String, body: String, about key: SessionStates.Key) {
    guard let center else { return }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = Self.userInfo(for: key)
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    if known == .allowed {
      center.add(request)
      return
    }
    Task {
      guard await requestAuthorization() == .allowed else { return }
      try? await center.add(request)
    }
  }

  func authorization() async -> NotificationAuthorization {
    guard let center else { return .unavailable }
    known = Self.mapped(await center.notificationSettings().authorizationStatus)
    return known
  }

  /// The system dialog appears on the first call only; later ones answer
  /// with what was settled then, whether or not it was a yes.
  func requestAuthorization() async -> NotificationAuthorization {
    guard let center else { return .unavailable }
    if (try? await center.requestAuthorization(options: [.alert, .sound])) == true {
      known = .allowed
      return known
    }
    return await authorization()
  }

  private static func mapped(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
    switch status {
    case .notDetermined: .notAsked
    case .denied: .refused
    default: .allowed
    }
  }

  private static func userInfo(for key: SessionStates.Key) -> [String: String] {
    switch key {
    case .session(let id): ["session": id.uuidString]
    case .worktree(let id): ["worktree": id]
    }
  }

  nonisolated static func key(from userInfo: [AnyHashable: Any]) -> SessionStates.Key? {
    if let raw = userInfo["session"] as? String, let id = UUID(uuidString: raw) {
      return .session(id)
    }
    if let worktree = userInfo["worktree"] as? String {
      return .worktree(worktree)
    }
    return nil
  }
}

extension UserNotificationNotifier: UNUserNotificationCenterDelegate {
  /// The default hides banners while the app is frontmost; the tab this is
  /// about is not the one on screen, so show it anyway.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    let userInfo = response.notification.request.content.userInfo
    guard let key = Self.key(from: userInfo) else { return }
    await MainActor.run {
      NSApp.activate()
      onActivate?(key)
    }
  }
}
