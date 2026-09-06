import Foundation

/// Why a child was ended by this side rather than exiting on its own.
public enum ProcessStop: Equatable, Sendable {
  /// It was still running when `timeout` ran out.
  case timedOut(after: Duration)
  /// `ProcessStopper.stop()` was called: the user asked.
  case stopped
}

/// A handle the caller keeps to end a running child: `stop()` sends SIGHUP,
/// then SIGKILL a few seconds later if it is still there. Made before the
/// child starts and handed to `ProcessRunner`, so the layers between the
/// user's button and the process need not know each other.
///
/// SIGHUP, not SIGTERM: hooks run through an interactive login shell, and
/// bash and zsh ignore SIGTERM when interactive, so `Process.terminate()`
/// did nothing to them. Sent to the child's process group, not the child:
/// `Process` makes each child a group leader, and a shell with no terminal
/// exits on SIGHUP without passing it to the `sleep` or `npm` it was
/// running, which would otherwise live on as an orphan.
///
/// A stop that arrives before a child is attached is kept and applied to
/// the next one, so a click that lands between two hook stages still stops
/// the hook that follows.
public final class ProcessStopper: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var pending: ProcessStop?
  private var applied: ProcessStop?

  public init() {}

  public func stop() {
    stop(.stopped)
  }

  /// The reason this stopper ended the child it was attached to, once it
  /// has; `nil` while the child runs or after it exited on its own.
  public var reason: ProcessStop? {
    lock.withLock { applied }
  }

  func stop(_ reason: ProcessStop) {
    let target: Process? = lock.withLock {
      guard applied == nil else { return nil }
      guard let process else {
        pending = reason
        return nil
      }
      applied = reason
      return process
    }
    if let target { Self.end(target) }
  }

  /// Called by the runner once the child is running. A stop asked for
  /// earlier is carried out now.
  func attach(_ process: Process) {
    let reason: ProcessStop? = lock.withLock {
      self.process = process
      guard let pending, applied == nil else { return nil }
      self.pending = nil
      applied = pending
      return pending
    }
    if reason != nil { Self.end(process) }
  }

  /// SIGKILL follows for a child that ignores or traps SIGHUP.
  static let killGrace: TimeInterval = 3

  private static func end(_ process: Process) {
    guard process.isRunning else { return }
    let pid = process.processIdentifier
    if kill(-pid, SIGHUP) != 0 { kill(pid, SIGHUP) }
    // The group only, no fallback to the pid: by now the leader may have
    // exited and the number gone to an unrelated process. A group id is
    // never reused while a member is alive.
    DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
      kill(-pid, SIGKILL)
    }
  }
}
