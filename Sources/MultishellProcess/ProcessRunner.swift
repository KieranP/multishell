import Foundation

public struct ProcessOutput: Sendable {
  public let standardOutput: String
  public let standardError: String
  public let status: Int32

  public var succeeded: Bool { status == 0 }
}

public struct ProcessFailure: Error, CustomStringConvertible {
  public let executable: String
  public let arguments: [String]
  public let status: Int32
  public let message: String

  public init(executable: String, arguments: [String], status: Int32, message: String) {
    self.executable = executable
    self.arguments = arguments
    self.status = status
    self.message = message
  }

  public var description: String {
    "\(executable) \(arguments.joined(separator: " ")) failed (\(status)): \(message)"
  }
}

/// Runs a child process and captures its output.
public struct ProcessRunner: Sendable {
  public init() {}

  /// Throws `ProcessFailure` on a non-zero exit.
  public func run(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:]
  ) async throws -> String {
    let output = try await capture(executable, arguments, in: directory, environment: environment)
    guard output.succeeded else {
      throw ProcessFailure(
        executable: executable.lastPathComponent,
        arguments: arguments,
        status: output.status,
        message: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
    return output.standardOutput
  }

  /// Returns the exit status instead of throwing.
  public func capture(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:]
  ) async throws -> ProcessOutput {
    try await withCheckedThrowingContinuation { continuation in
      do {
        try launch(executable, arguments, in: directory, environment: environment) { output in
          continuation.resume(returning: output)
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

/// Starts the child and calls `completion` once it has exited and both pipes
/// have hit EOF. Nothing blocks: the pipes are drained by readability
/// handlers and the exit by the termination handler.
///
/// The blocking form deadlocked under load. A wait inside a `Task` holds a
/// cooperative-pool thread, one per core, and the pipe readers it waited on
/// were GCD blocks; with enough concurrent children GCD ran out of threads for
/// the readers, the children blocked on full pipes, and the waits never
/// returned.
private func launch(
  _ executable: URL,
  _ arguments: [String],
  in directory: URL,
  environment: [String: String],
  completion: @escaping @Sendable (ProcessOutput) -> Void
) throws {
  let process = Process()
  process.executableURL = executable
  process.arguments = arguments
  process.currentDirectoryURL = directory
  if !environment.isEmpty {
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
  }

  let outPipe = Pipe()
  let errPipe = Pipe()
  process.standardOutput = outPipe
  process.standardError = errPipe

  // Both pipes drain concurrently: whichever is read second could otherwise
  // fill its 64 KiB buffer and block the child forever. Each buffer is
  // written only from its own handle's serial handler queue, and the group
  // orders those writes before the read in `notify`.
  let group = DispatchGroup()
  let out = PipeBuffer(outPipe, group: group)
  let err = PipeBuffer(errPipe, group: group)
  group.enter()
  process.terminationHandler = { _ in group.leave() }

  do {
    try process.run()
  } catch {
    // A missing executable or working directory fails here, every five
    // seconds for an unreachable worktree. The handlers hold their buffers,
    // which hold the group, which nothing else releases; and the pipes stay
    // open waiting for an EOF no child will send.
    out.cancel()
    err.cancel()
    try? outPipe.fileHandleForWriting.close()
    try? errPipe.fileHandleForWriting.close()
    throw error
  }

  group.notify(queue: .global()) {
    completion(
      ProcessOutput(
        standardOutput: String(decoding: out.data, as: UTF8.self),
        standardError: String(decoding: err.data, as: UTF8.self),
        status: process.terminationStatus
      ))
  }
}

/// Collects one pipe to EOF without blocking a thread.
private final class PipeBuffer: @unchecked Sendable {
  private(set) var data = Data()
  private let handle: FileHandle

  init(_ pipe: Pipe, group: DispatchGroup) {
    handle = pipe.fileHandleForReading
    group.enter()
    handle.readabilityHandler = { [self] handle in
      let chunk = handle.availableData
      guard !chunk.isEmpty else {
        handle.readabilityHandler = nil
        group.leave()
        return
      }
      data.append(chunk)
    }
  }

  /// For a child that never started: stop waiting and release the pipe.
  func cancel() {
    handle.readabilityHandler = nil
    try? handle.close()
  }
}
