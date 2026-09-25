import Foundation
import Subprocess
import Synchronization
import System

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
  /// `timeout`, or stopped, is ended and reported with `stop` set.
  public func capture(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> ProcessOutput {
    let stopper = stopper ?? ProcessStopper()
    let nullInput = try DetachedLaunch.NullDevice()
    defer { nullInput.close() }
    let outPipe = try makePipe()
    let errPipe: (reading: FileHandle, writing: FileDescriptor)
    do {
      errPipe = try makePipe()
    } catch {
      try? outPipe.reading.close()
      try? outPipe.writing.close()
      throw error
    }

    // Ours, not Subprocess's, which traps at the descriptor limit; see
    // dependencies.md. Both drain at once, or one fills and blocks.
    let drained = DispatchGroup()
    let out = PipeBuffer(outPipe.reading, group: drained)
    let err = PipeBuffer(errPipe.reading, group: drained)
    let child = RunningChild()

    let status: TerminationStatus
    do {
      // The write ends are Subprocess's to close, failure or not.
      let (outWriting, errWriting) = (outPipe.writing, errPipe.writing)
      status = try await DetachedLaunch.shielded {
        try await Subprocess.run(
          .path(FilePath(executable.path)), arguments: Arguments(arguments),
          environment: DetachedLaunch.environment(overriding: environment),
          workingDirectory: FilePath(directory.path),
          platformOptions: DetachedLaunch.platformOptions,
          input: .fileDescriptor(nullInput.descriptor, closeAfterSpawningProcess: false),
          output: .fileDescriptor(outWriting, closeAfterSpawningProcess: true),
          error: .fileDescriptor(errWriting, closeAfterSpawningProcess: true)
        ) { execution in
          nullInput.close()
          child.started(execution.processIdentifier.value)
          stopper.attach(child)
          if let timeout { Self.arm(timeout, for: child, stopper: stopper) }
          // Marked before Subprocess reaps it, so no stop signals a reused pid.
          await child.waitForExit()
          child.exited()
        }.terminationStatus
      }
    } catch {
      // A missing executable or directory fails here, and no EOF will come.
      out.cancel()
      err.cancel()
      throw error
    }

    await Self.drain(out, err, group: drained)
    return ProcessOutput(
      standardOutput: String(decoding: out.data, as: UTF8.self),
      standardError: String(decoding: err.data, as: UTF8.self),
      status: DetachedLaunch.status(status),
      stop: stopper.reason
    )
  }

  /// A descendant that inherited the pipes holds them open after the child
  /// is gone, so EOF may never come; the buffer is already drained.
  static func drain(_ out: PipeBuffer, _ err: PipeBuffer, group: DispatchGroup) async {
    // Weak, or each run's read ends stay open until the timer fires. An
    // unfinished buffer keeps itself alive through its readability handler.
    DispatchQueue.global().asyncAfter(deadline: .now() + eofGraceAfterExit) {
      [weak out, weak err] in
      out?.finish()
      err?.finish()
    }
    await withCheckedContinuation { continuation in
      group.notify(queue: .global()) { continuation.resume() }
    }
  }

  private static func arm(_ timeout: Duration, for child: RunningChild, stopper: ProcessStopper) {
    let seconds =
      Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
    DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
      if child.isRunning { stopper.stop(.timedOut(after: timeout)) }
    }
  }
}

/// A child between its start and Subprocess reaping it: what a stop signals.
/// `exited()` comes before the reap, so a pid read under the lock is ours.
final class RunningChild: Sendable {
  private let state = Mutex<(pid: pid_t, isRunning: Bool)>((0, false))

  var isRunning: Bool { signalling { _ in } != nil }

  func started(_ pid: pid_t) {
    state.withLock { $0 = (pid, true) }
  }

  func exited() {
    state.withLock { $0.isRunning = false }
  }

  /// Runs `body` with the pid while the child is alive, under the lock
  /// `exited()` takes, so the pid cannot be reaped and reused meanwhile.
  func signalling<Result: Sendable>(_ body: (pid_t) -> Result) -> Result? {
    state.withLock { state in
      guard state.isRunning, !Self.hasExited(state.pid) else { return nil }
      return body(state.pid)
    }
  }

  /// Returns once the child has exited, leaving it for Subprocess to reap.
  func waitForExit() async {
    let pid = state.withLock { $0.pid }
    await withCheckedContinuation { continuation in
      let source = DispatchSource.makeProcessSource(
        identifier: pid, eventMask: .exit, queue: .global())
      source.setEventHandler { source.cancel() }
      source.setCancelHandler { continuation.resume() }
      source.resume()
      // A child gone before the source was registered sends it nothing.
      if Self.hasExited(pid) { source.cancel() }
    }
  }

  /// A zombie, reaped, or on its way out: a signal would change nothing, and
  /// the stop would be reported beside the child's own status.
  private static func hasExited(_ pid: pid_t) -> Bool {
    var info = siginfo_t()
    guard waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT) == 0 else { return true }
    guard info.si_pid != pid else { return true }
    return ProcessAncestry.kinfo(pid).map { $0.kp_proc.p_flag & P_WEXIT != 0 } ?? true
  }
}

/// A pipe's 64 KiB buffer is all a child can leave unread when it exits, and
/// one readability callback takes it. The margin is for a loaded machine.
private let eofGraceAfterExit: TimeInterval = 1

/// Both ends of a new pipe, or `PipeUnavailable`. Not `Pipe()`, which cannot
/// fail and so returns two handles on descriptor 0 at the limit.
func makePipe() throws -> (reading: FileHandle, writing: FileDescriptor) {
  var descriptors: [Int32] = [-1, -1]
  guard pipe(&descriptors) == 0 else { throw PipeUnavailable(code: errno) }
  // macOS has no pipe2, so a fork between the two calls still inherits them.
  for descriptor in descriptors { _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC) }
  return (
    FileHandle(fileDescriptor: descriptors[0], closeOnDealloc: true),
    FileDescriptor(rawValue: descriptors[1])
  )
}

/// Collects one pipe to EOF without blocking a thread.
final class PipeBuffer: Sendable {
  private let state = Mutex<(buffer: Data, finished: Bool)>((Data(), false))
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
    state.withLock { $0.buffer }
  }

  private func append(_ chunk: Data) {
    state.withLock {
      if !$0.finished { $0.buffer.append(chunk) }
    }
  }

  /// Stops reading and counts the pipe as drained. Only the first call does
  /// anything.
  func finish() {
    let first = state.withLock {
      defer { $0.finished = true }
      return !$0.finished
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
