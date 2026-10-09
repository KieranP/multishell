import Darwin
import Synchronization

/// Counts this process's forks: `fork()` runs the atfork handlers, and
/// `posix_spawn` does not.
enum ForkCount {
  static let forks = Atomic(0)
  private static let registered: Void = {
    pthread_atfork({ Self.forks.add(1, ordering: .relaxed) }, nil, nil)
  }()

  static func watch() { _ = registered }
}
