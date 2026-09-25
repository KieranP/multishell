import Foundation
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
    let nullInput = try NullDevice()
    defer { nullInput.close() }
    let (outputPipe, errorPipe) = try Self.makePipePair()

    // Ours, not Subprocess's, which traps at the descriptor limit; see
    // dependencies.md. Both drain at once, or one fills and blocks.
    let drained = DispatchGroup()
    let standardOutput = PipeBuffer(outputPipe.reading, group: drained)
    let standardError = PipeBuffer(errorPipe.reading, group: drained)
    let child = RunningChild()

    let status: Int32
    do {
      // The write ends are Subprocess's to close, failure or not.
      status = try await DetachedLaunch.run(
        executable, arguments, in: directory, environment: environment,
        input: nullInput.descriptor, output: outputPipe.writing, error: errorPipe.writing,
        closingOutputsAfterSpawn: true
      ) { pid in
        nullInput.close()
        child.started(pid)
        stopper.attach(child)
        if let timeout { Self.armTimeout(timeout, for: child, stopper: stopper) }
        // Marked before Subprocess reaps it, so no stop signals a reused pid.
        await child.waitForExit()
        child.exited()
      }
    } catch {
      // A missing executable or directory fails here, and no EOF will come.
      standardOutput.cancel()
      standardError.cancel()
      throw error
    }

    await Self.awaitEOF(standardOutput, standardError, group: drained)
    return ProcessOutput(
      standardOutput: String(decoding: standardOutput.data, as: UTF8.self),
      standardError: String(decoding: standardError.data, as: UTF8.self),
      status: status,
      stop: stopper.reason
    )
  }

  /// Both pipes or neither: the first is closed where the second fails.
  private static func makePipePair() throws -> (
    output: PipeBuffer.PipeEnds, error: PipeBuffer.PipeEnds
  ) {
    let output = try PipeBuffer.makePipe()
    do {
      return (output, try PipeBuffer.makePipe())
    } catch {
      try? output.reading.close()
      try? output.writing.close()
      throw error
    }
  }

  /// A descendant that inherited the pipes holds them open after the child
  /// is gone, so EOF may never come; the buffer is already drained.
  static func awaitEOF(
    _ standardOutput: PipeBuffer, _ standardError: PipeBuffer, group: DispatchGroup
  ) async {
    // Weak, or each run's read ends stay open until the timer fires. An
    // unfinished buffer keeps itself alive through its readability handler.
    DispatchQueue.global().asyncAfter(deadline: .now() + eofGraceAfterExit) {
      [weak standardOutput, weak standardError] in
      standardOutput?.finish()
      standardError?.finish()
    }
    await withCheckedContinuation { continuation in
      group.notify(queue: .global()) { continuation.resume() }
    }
  }

  private static func armTimeout(
    _ timeout: Duration, for child: RunningChild, stopper: ProcessStopper
  ) {
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
