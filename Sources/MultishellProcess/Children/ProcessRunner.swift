import Foundation
import Subprocess
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
    let outPipe = try PipeBuffer.makePipe()
    let errPipe: (reading: FileHandle, writing: FileDescriptor)
    do {
      errPipe = try PipeBuffer.makePipe()
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
      status: DetachedLaunch.exitCode(of: status),
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

/// A pipe's 64 KiB buffer is all a child can leave unread when it exits, and
/// one readability callback takes it. The margin is for a loaded machine.
private let eofGraceAfterExit: TimeInterval = 1
