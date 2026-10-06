import Foundation
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct NotificationCenterMainActorObserversTests {
  private let name = Notification.Name("NotificationCenterMainActorObserversTests")

  @Test func anObserverRunsForItsOwnerWithoutKeepingItAlive() {
    let center = NotificationCenter()
    let runs = RunCount()
    var owner: Owner? = Owner()
    weak let watched = owner
    let tokens = center.observe([(name, runs.counting)], for: owner!)
    defer { tokens.forEach(center.removeObserver) }

    center.post(name: name, object: nil)
    owner = nil
    center.post(name: name, object: nil)

    #expect(watched == nil)
    #expect(runs.count == 1)
  }

  @Test func anObserverOfOneObjectIgnoresTheSameNameFromAnother() {
    let center = NotificationCenter()
    let runs = RunCount()
    let owner = Owner()
    let watched = NSObject()
    let tokens = center.observe([(name, runs.counting)], from: watched, for: owner)
    defer { tokens.forEach(center.removeObserver) }

    center.post(name: name, object: NSObject())
    center.post(name: name, object: watched)

    #expect(runs.count == 1)
  }

  private final class Owner: Sendable {}

  @MainActor
  private final class RunCount {
    private(set) var count = 0

    var counting: @MainActor @Sendable (Owner) -> Void {
      { [self] _ in count += 1 }
    }
  }
}
