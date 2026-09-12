import Foundation

/// Why a child was ended by this side rather than exiting on its own.
public enum ProcessStop: Equatable, Sendable {
  /// It was still running when `timeout` ran out.
  case timedOut(after: Duration)
  /// `ProcessStopper.stop()` was called: the user asked.
  case stopped
}

/// A handle to end a running child: SIGHUP then SIGKILL, to the process
/// group. Not SIGTERM, which an interactive bash or zsh ignores.
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

  /// Whether a stop has been asked for, child or no child: work with no
  /// process to signal reads this to end itself.
  public var isStopped: Bool {
    lock.withLock { pending != nil || applied != nil }
  }

  func stop(_ reason: ProcessStop) {
    let target: Process? = lock.withLock {
      guard applied == nil else { return nil }
      guard let process else {
        pending = reason
        return nil
      }
      // A child already gone was not stopped by this: a timeout dies with the
      // run that armed it, the user's ask carries to the next child.
      guard process.isRunning else {
        if reason == .stopped { pending = reason }
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
    // The group where the child leads one, which is how `Process` spawns it;
    // the child alone where the signal says it does not.
    let leadsGroup = kill(-pid, SIGHUP) == 0
    if !leadsGroup { kill(pid, SIGHUP) }
    DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
      guard leadsGroup else {
        if process.isRunning { kill(pid, SIGKILL) }
        return
      }
      // The group, not the shell: a grandchild trapping SIGHUP outlives it.
      // An empty group answers ESRCH, so what answers here is ours.
      guard kill(-pid, 0) == 0 else { return }
      kill(-pid, SIGKILL)
    }
  }
}
