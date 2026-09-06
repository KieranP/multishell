import AppKit
import MultishellAppCore
import MultishellCore
@preconcurrency import UserNotifications

/// `SessionNotifier` on `UNUserNotificationCenter`, which needs a bundle: a
/// bare binary from `swift run` has none, and asking the center there
/// crashes, so this does nothing outside an app bundle. Authorization is
/// requested on first use.
@MainActor
final class UserNotificationNotifier: NSObject, SessionNotifier {
  var onActivate: (@MainActor (SessionStates.Key) -> Void)?

  private let center: UNUserNotificationCenter?
  private var authorizationRequested = false

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
    if authorizationRequested {
      center.add(request)
      return
    }
    authorizationRequested = true
    Task {
      guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
        return
      }
      try? await center.add(request)
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
