import Foundation

public struct ProcessOutput: Sendable {
  public let standardOutput: String
  public let standardError: String
  public let status: Int32
  /// Set when this side ended the child: the timeout ran out, or the
  /// caller's `ProcessStopper` was used. `status` is then the signal's.
  public let stop: ProcessStop?

  public init(
    standardOutput: String, standardError: String, status: Int32, stop: ProcessStop? = nil
  ) {
    self.standardOutput = standardOutput
    self.standardError = standardError
    self.status = status
    self.stop = stop
  }

  public var succeeded: Bool { status == 0 }
}

/// Runs a child process and captures its output.
public struct ProcessRunner: Sendable {
  public init() {}

  /// Throws `ProcessFailure` on a non-zero exit.
  public func run(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> String {
    let output = try await capture(
      executable, arguments, in: directory, environment: environment, timeout: timeout,
      stopper: stopper)
    guard output.succeeded else {
      throw ProcessFailure(
        executable: executable.lastPathComponent,
        arguments: arguments,
        status: output.status,
        message: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines),
        stop: output.stop
      )
    }
    return output.standardOutput
  }

  /// Returns the exit status instead of throwing. A child still running at
  /// `timeout`, or when `stopper.stop()` is called, is ended the way
  /// `ProcessStopper` does it and reported with `stop` set.
  public func capture(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> ProcessOutput {
    try await withCheckedThrowingContinuation { continuation in
      do {
        try launch(
          executable, arguments, in: directory, environment: environment, timeout: timeout,
          stopper: stopper ?? ProcessStopper()
        ) { output in
          continuation.resume(returning: output)
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

/// Starts the child and calls `completion` once it has exited and both pipes
/// have hit EOF, or a moment after the exit if EOF never comes. Nothing
/// blocks: the pipes are drained by readability handlers and the exit by the
/// termination handler.
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
  timeout: Duration?,
  stopper: ProcessStopper,
  completion: @escaping @Sendable (ProcessOutput) -> Void
) throws {
  let process = Process()
  process.executableURL = executable
  process.arguments = arguments
  process.currentDirectoryURL = directory
  if !environment.isEmpty {
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
  }

  let outPipe = try makePipe()
  let errPipe = try makePipe()
  process.standardOutput = outPipe.writing
  process.standardError = errPipe.writing
  // A child that reads stdin would otherwise wait on the app's, forever.
  process.standardInput = FileHandle.nullDevice

  // Both pipes drain concurrently: whichever is read second could otherwise
  // fill its 64 KiB buffer and block the child forever. Each buffer is
  // written only from its own handle's serial handler queue, and the group
  // orders those writes before the read in `notify`.
  let group = DispatchGroup()
  let out = PipeBuffer(outPipe.reading, group: group)
  let err = PipeBuffer(errPipe.reading, group: group)
  group.enter()
  process.terminationHandler = { [weak out, weak err] _ in
    // A descendant that inherited the pipes (`server &` in a hook) holds them
    // open after the child is gone, so EOF would arrive when the server
    // stops. Everything the child wrote is in the kernel's buffer by now and
    // the readers take it within milliseconds; after that, stop waiting.
    // Weak, so on the usual path the pipes close with the completion rather
    // than a second later.
    DispatchQueue.global().asyncAfter(deadline: .now() + eofGraceAfterExit) {
      [weak out, weak err] in
      out?.finish()
      err?.finish()
    }
    group.leave()
  }

  do {
    try process.run()
  } catch {
    // A missing executable or working directory fails here, every five
    // seconds for an unreachable worktree. The handlers hold their buffers,
    // which hold the group, which nothing else releases; and the pipes stay
    // open waiting for an EOF no child will send.
    out.cancel()
    err.cancel()
    try? outPipe.writing.close()
    try? errPipe.writing.close()
    throw error
  }
  // The child has its copies; the parent's must go or EOF never comes.
  // `Process` does this itself for a `Pipe`, not for handles it was given.
  try? outPipe.writing.close()
  try? errPipe.writing.close()

  stopper.attach(process)
  if let timeout {
    let seconds =
      Double(timeout.components.seconds)
      + Double(timeout.components.attoseconds) / 1e18
    DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
      if process.isRunning { stopper.stop(.timedOut(after: timeout)) }
    }
  }

  group.notify(queue: .global()) {
    completion(
      ProcessOutput(
        standardOutput: String(decoding: out.data, as: UTF8.self),
        standardError: String(decoding: err.data, as: UTF8.self),
        status: process.terminationStatus,
        stop: stopper.reason
      ))
  }
}

/// A pipe's 64 KiB buffer is all a child can leave unread when it exits, and
/// one readability callback takes it. The margin is for a loaded machine.
private let eofGraceAfterExit: TimeInterval = 1

/// Both ends of a new pipe, or `PipeUnavailable`.
///
/// Not `Pipe()`: it cannot fail, so at the descriptor limit it returns two
/// handles on descriptor 0. The child then writes to the app's stdin, the
/// reader sees stdin's EOF at once, and `git worktree list` seems to say the
/// project has no worktrees, which would drop every one of its tabs.
private func makePipe() throws -> (reading: FileHandle, writing: FileHandle) {
  var descriptors: [Int32] = [-1, -1]
  guard pipe(&descriptors) == 0 else { throw PipeUnavailable(code: errno) }
  return (
    FileHandle(fileDescriptor: descriptors[0], closeOnDealloc: true),
    FileHandle(fileDescriptor: descriptors[1], closeOnDealloc: true)
  )
}

/// Collects one pipe to EOF without blocking a thread.
private final class PipeBuffer: @unchecked Sendable {
  private var buffer = Data()
  private var finished = false
  private let lock = NSLock()
  private let handle: FileHandle
  private let group: DispatchGroup

  init(_ reading: FileHandle, group: DispatchGroup) {
    handle = reading
    self.group = group
    group.enter()
    handle.readabilityHandler = { [self] handle in
      let chunk = handle.availableData
      if chunk.isEmpty {
        finish()
      } else {
        append(chunk)
      }
    }
  }

  var data: Data {
    lock.withLock { buffer }
  }

  private func append(_ chunk: Data) {
    lock.withLock {
      if !finished { buffer.append(chunk) }
    }
  }

  /// Stops reading and counts the pipe as drained. Reached at EOF, when the
  /// child has exited and something else still holds the pipe, or when the
  /// child never started; only the first call does anything.
  func finish() {
    let first = lock.withLock {
      defer { finished = true }
      return !finished
    }
    guard first else { return }
    handle.readabilityHandler = nil
    group.leave()
  }

  /// For a child that never started: stop waiting and release the pipe.
  func cancel() {
    finish()
    try? handle.close()
  }
}
