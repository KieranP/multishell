import Foundation

extension NotificationCenter {
  /// Each change run on `owner` on the main thread while it lives, held
  /// weakly; the caller keeps the tokens to remove.
  @MainActor
  func observe<Owner: AnyObject & Sendable>(
    _ changes: [(NSNotification.Name, @MainActor @Sendable (Owner) -> Void)],
    for owner: Owner,
    from object: Any? = nil,
  ) -> [any NSObjectProtocol] {
    changes.map { name, change in
      addObserver(forName: name, object: object, queue: .main) { [weak owner] _ in
        MainActor.assumeIsolated { owner.map(change) }
      }
    }
  }
}
