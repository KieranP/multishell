import AppKit
import MultishellAppCore
import MultishellCore
@preconcurrency import UserNotifications

/// `SessionNotifier` on `UNUserNotificationCenter`, which needs a bundle and
/// crashes without one, so this does nothing outside an app bundle.
@MainActor
final class UserNotificationNotifier: NSObject, SessionNotifier {
  var onActivate: (@MainActor (SessionStates.Key) -> Void)?

  private let center: UNUserNotificationCenter?
  /// The last answer, so a settled permission costs no hop before posting.
  private var known = NotificationAuthorization.notAsked
  /// The request each identifier is waiting to add once the permission dialog
  /// is answered. A withdrawal drops the entry; the newest wins.
  private var pendingAdds: [String: UNNotificationRequest] = [:]

  override init() {
    center = Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    super.init()
    center?.delegate = self
  }

  /// One live banner per pane, the request carrying the key as its
  /// identifier, so a second report replaces the first rather than stacking.
  func notify(title: String, body: String, about key: SessionStates.Key) {
    guard let center else { return }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = Self.userInfo(for: key)
    let identifier = Self.identifier(for: key)
    let request = UNNotificationRequest(
      identifier: identifier, content: content, trigger: nil)
    if known == .allowed {
      center.add(request)
      return
    }
    let waiting = pendingAdds.updateValue(request, forKey: identifier) != nil
    // One task per identifier: a second report while the first waits
    // replaces what that task will add rather than queueing behind it.
    guard !waiting else { return }
    Task {
      let allowed = await requestAuthorization() == .allowed
      guard let latest = pendingAdds.removeValue(forKey: identifier), allowed else { return }
      try? await center.add(latest)
    }
  }

  func withdraw(about key: SessionStates.Key) {
    let identifier = Self.identifier(for: key)
    pendingAdds.removeValue(forKey: identifier)
    center?.removeDeliveredNotifications(withIdentifiers: [identifier])
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

  /// Stable for the life of a pane and distinct across the two kinds of key,
  /// the prefix saying which without relying on a path never being a UUID.
  nonisolated static func identifier(for key: SessionStates.Key) -> String {
    switch key {
    case .session(let id): "session:\(id.uuidString)"
    case .worktree(let id): "worktree:\(id)"
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
