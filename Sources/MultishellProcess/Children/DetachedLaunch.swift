import Foundation
import Subprocess
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

  /// Starts a child on descriptors the caller opened and returns its exit
  /// code, `whileRunning` being handed its pid between spawn and exit.
  static func run(
    _ executable: URL, _ arguments: [String], in directory: URL,
    environment: [String: String],
    input: FileDescriptor, output: FileDescriptor, error: FileDescriptor,
    closingOutputsAfterSpawn: Bool,
    whileRunning: @escaping @Sendable (pid_t) async -> Void
  ) async throws -> Int32 {
    try await shielded {
      let result = try await Subprocess.run(
        .path(FilePath(executable.path)), arguments: Arguments(arguments),
        environment: Self.environment(overriding: environment),
        workingDirectory: FilePath(directory.path),
        platformOptions: platformOptions,
        input: .fileDescriptor(input, closeAfterSpawningProcess: false),
        output: .fileDescriptor(output, closeAfterSpawningProcess: closingOutputsAfterSpawn),
        error: .fileDescriptor(error, closeAfterSpawningProcess: closingOutputsAfterSpawn)
      ) { execution in await whileRunning(execution.processIdentifier.value) }
      return exitCode(of: result.terminationStatus)
    }
  }

  /// Out of reach of the caller's cancellation, which Subprocess answers with
  /// SIGKILL: `ProcessStopper` is what ends a child here.
  private static func shielded<Value: Sendable>(
    _ body: @escaping @Sendable () async throws -> Value
  ) async throws -> Value {
    try await Task { try await body() }.value
  }

  private static func environment(overriding values: [String: String]) -> Environment {
    .inherit.updating(
      Dictionary(uniqueKeysWithValues: values.map { (Environment.Key(stringLiteral: $0), $1) }))
  }

  /// The exit status, or the signal's number, as `Process` reported it.
  private static func exitCode(of status: TerminationStatus) -> Int32 {
    switch status {
    case .exited(let code), .signaled(let code): code
    }
  }
}
