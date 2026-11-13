@testable import MultishellAppCore

@MainActor
final class FakeNotifier: SessionNotifier {
  var onActivate: (@MainActor (SessionStates.Key) -> Void)?
  var posted: [(title: String, body: String, key: SessionStates.Key)] = []
  /// What the system would answer, and how often it was asked.
  var answer = NotificationAuthorization.allowed
  var authorizationRequests = 0
  /// Keys whose banner was taken back, in the order they were.
  var withdrawn: [SessionStates.Key] = []
  var withdrewEverything = false
  func notify(title: String, body: String, about key: SessionStates.Key) {
    posted.append((title, body, key))
  }
  func withdraw(about key: SessionStates.Key) {
    withdrawn.append(key)
  }
  func withdrawEverything() {
    withdrewEverything = true
  }
  func authorization() async -> NotificationAuthorization { answer }
  func requestAuthorization() async -> NotificationAuthorization {
    authorizationRequests += 1
    return answer
  }
}
