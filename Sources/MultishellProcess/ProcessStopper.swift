import Foundation
import Synchronization

/// A handle to end a running child: SIGHUP then SIGKILL, to the process
/// group. Not SIGTERM, which an interactive bash or zsh ignores.
public final class ProcessStopper: Sendable {
  private struct State {
    var process: RunningChild?
    var pending: ProcessStop?
    var applied: ProcessStop?
  }

  private let state = Mutex(State())

  public init() {}

  public func stop() {
    stop(.stopped)
  }

  /// The reason this stopper ended the child it was attached to, once it
  /// has; `nil` while the child runs or after it exited on its own.
  public var reason: ProcessStop? {
    state.withLock { $0.applied }
  }

  /// Whether a stop has been asked for, child or no child: work with no
  /// process to signal reads this to end itself.
  public var isStopped: Bool {
    state.withLock { $0.pending != nil || $0.applied != nil }
  }

  func stop(_ reason: ProcessStop) {
    state.withLock { state in
      guard state.applied == nil else { return }
      guard let process = state.process else {
        state.pending = reason
        return
      }
      // A child already gone was not stopped by this: a timeout dies with the
      // run that armed it, the user's ask carries to the next child.
      guard Self.end(process) else {
        if reason == .stopped { state.pending = reason }
        return
      }
      state.applied = reason
    }
  }

  /// Called by the runner once the child is running. A stop asked for earlier
  /// was meant for this child, so its run reads as stopped though it exited.
  func attach(_ process: RunningChild) {
    state.withLock { state in
      state.process = process
      guard let pending = state.pending, state.applied == nil else { return }
      _ = Self.end(process)
      state.pending = nil
      state.applied = pending
    }
  }

  /// SIGKILL follows for a child that ignores or traps SIGHUP.
  static let killGrace: TimeInterval = 3

  /// False for a child already gone. Not Subprocess's teardown, which stops once
  /// the child exits: a grandchild trapping SIGHUP would outlive the shell.
  private static func end(_ process: RunningChild) -> Bool {
    let hungUp = {
      var now = timeval()
      gettimeofday(&now, nil)
      return now
    }()
    let signalled = process.signalling { pid in
      // The group where the child leads one, as its own session's leader does;
      // the child alone where the signal says it does not.
      let leadsGroup = kill(-pid, SIGHUP) == 0
      if !leadsGroup { kill(pid, SIGHUP) }
      return (pid: pid, leadsGroup: leadsGroup)
    }
    guard let (pid, leadsGroup) = signalled else { return false }
    DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
      guard leadsGroup else {
        _ = process.signalling { kill($0, SIGKILL) }
        return
      }
      // The group, not the shell: a grandchild trapping SIGHUP outlives it.
      // The pid may have been reused by then, so the group is checked first.
      guard ProcessGroup.isStillOurs(hungUpAt: hungUp, group: pid) else { return }
      kill(-pid, SIGKILL)
    }
    return true
  }
}
