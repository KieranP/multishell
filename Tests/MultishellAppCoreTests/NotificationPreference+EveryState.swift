@testable import MultishellCore

extension NotificationPreference {
  static let everyState = NotificationPreference(
    notifiesOnAttention: true,
    notifiesOnFailure: true,
    notifiesOnDone: true,
  )
}
