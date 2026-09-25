import Foundation
import Subprocess
import Synchronization
import System

/// How every child here is started, and what its ending reads as.
enum DetachedLaunch {
  /// A session of its own, so no controlling terminal: an interactive shell
  /// outside a terminal's foreground group stops itself on SIGTTIN.
  static var platformOptions: PlatformOptions {
    var options = PlatformOptions()
    // Not `createSession`, which forks the whole app before each spawn.
    options.preSpawnProcessConfigurator = { attributes, _ in
      var flags: Int16 = 0
      var result = posix_spawnattr_getflags(&attributes, &flags)
      if result == 0 {
        result = posix_spawnattr_setflags(&attributes, flags | Int16(POSIX_SPAWN_SETSID))
      }
      if result != 0 { throw Errno(rawValue: result) }
    }
    return options
  }

  /// Out of reach of the caller's cancellation, which Subprocess answers with
  /// SIGKILL: `ProcessStopper` is what ends a child here.
  static func shielded<Value: Sendable>(
    _ body: @escaping @Sendable () async throws -> Value
  ) async throws -> Value {
    try await Task { try await body() }.value
  }

  /// Ours, not Subprocess's `.none` or `.discarded`: it opens `/dev/null` after
  /// taking the output descriptors, and traps on them when that open fails.
  final class NullDevice: Sendable {
    let descriptor: FileDescriptor
    private let isOpen = Mutex(true)

    init() throws {
      let descriptor = open("/dev/null", O_RDWR | O_CLOEXEC)
      guard descriptor >= 0 else { throw PipeUnavailable(code: errno) }
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

  static func environment(overriding values: [String: String]) -> Environment {
    .inherit.updating(
      Dictionary(uniqueKeysWithValues: values.map { (Environment.Key(stringLiteral: $0), $1) }))
  }

  /// The exit status, or the signal's number, as `Process` reported it.
  static func exitCode(of status: TerminationStatus) -> Int32 {
    switch status {
    case .exited(let code), .signaled(let code): code
    }
  }
}
