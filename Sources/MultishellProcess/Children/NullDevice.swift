import Foundation
import Synchronization
import System

/// Ours, not Subprocess's `.none` or `.discarded`: it opens `/dev/null` after
/// taking the output descriptors, and traps on them when that open fails.
final class NullDevice: Sendable {
  let descriptor: FileDescriptor
  private let isOpen = Mutex(true)

  init() throws {
    let descriptor = open("/dev/null", O_RDWR | O_CLOEXEC)
    guard descriptor >= 0 else { throw DescriptorUnavailable(code: errno) }
    self.descriptor = FileDescriptor(rawValue: descriptor)
  }

  /// Called once the child has it and again as the run ends; closes on the
  /// first.
  func close() {
    let wasOpen = isOpen.withLock { isOpen in
      defer { isOpen = false }
      return isOpen
    }
    if wasOpen { try? descriptor.close() }
  }
}
