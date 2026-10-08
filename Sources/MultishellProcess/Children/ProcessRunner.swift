import Foundation
import System

public struct ProcessRunner: Sendable {
  /// A pipe's 64 KiB buffer is all a child can leave unread when it exits, and
  /// one readability callback takes it. The margin is for a loaded machine.
  private static let eofGraceAfterExit: TimeInterval = 1

  public init() {}

  /// Throws `ProcessFailure` on a non-zero exit.
  public func run(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
    exitUsageProbe: ExitUsageProbe? = nil
  ) async throws -> String {
    let output = try await capture(
      executable, arguments, in: directory, environment: environment, timeout: timeout,
      stopper: stopper, exitUsageProbe: exitUsageProbe)
    guard output.succeeded else {
      throw ProcessFailure(
        executable: executable.lastPathComponent,
        arguments: arguments,
        status: output.status,
        message: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines),
        stopReason: output.stopReason
      )
    }
    return output.standardOutput
  }

  /// Throws only where the child could not start; a non-zero exit comes back
  /// in `status`, and a child ended at `timeout` or by `stopper` sets `stopReason`.
  public func capture(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
    exitUsageProbe: ExitUsageProbe? = nil
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
        child.markStarted(pid)
        stopper.attach(child)
        if let timeout { Self.armTimeout(timeout, for: child, stopper: stopper) }
        // Marked before Subprocess reaps it, so no stop signals a reused pid.
        await child.waitForExit()
        // A zombie still, Subprocess reaping it only once this returns.
        exitUsageProbe?.record(KernelResourceUsage.exitUsage(of: pid))
        child.markExited()
      }
    } catch {
      // A missing executable or directory fails here, and no EOF will come.
      standardOutput.cancel()
      standardError.cancel()
      throw error
    }

    // A signal is never a status of 0, so the child finished on its own; see
    // Docs/design/architecture.md.
    if status == 0 { stopper.withdrawTimeout(from: child) }
    await Self.awaitDrained(standardOutput, standardError, group: drained)
    return ProcessOutput(
      standardOutput: String(decoding: standardOutput.collected, as: UTF8.self),
      standardError: String(decoding: standardError.collected, as: UTF8.self),
      status: status,
      stopReason: stopper.appliedStop
    )
  }

  /// Both pipes or neither: the first is closed where the second fails.
  private static func makePipePair() throws -> (
    output: PipeDescriptors.Ends, error: PipeDescriptors.Ends
  ) {
    let output = try PipeDescriptors.make()
    do {
      return (output, try PipeDescriptors.make())
    } catch {
      try? output.reading.close()
      try? output.writing.close()
      throw error
    }
  }

  /// A descendant that inherited the pipes holds them open after the child
  /// is gone, so EOF may never come; the buffer is already drained.
  static func awaitDrained(
    _ standardOutput: PipeBuffer, _ standardError: PipeBuffer, group: DispatchGroup
  ) async {
    // Weak, or each run's read ends stay open until the timer fires. An
    // unfinished buffer keeps itself alive through its readability handler.
    DispatchQueue.global().asyncAfter(deadline: .now() + Self.eofGraceAfterExit) {
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
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout.inSeconds) {
      if child.isRunning { stopper.stop(.timedOut(after: timeout)) }
    }
  }
}
