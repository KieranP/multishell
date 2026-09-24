import Foundation

extension AppModel {
  /// For the polling paths' reads and the Trash. Microseconds on a local
  /// disk; on a dead mount each blocks until it times out.
  nonisolated static func offMain<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
    await Task.detached(priority: .utility) { work() }.value
  }
}
