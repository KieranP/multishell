import Foundation
import Synchronization

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
    return KernelProcessTable.record(of: pid).map { $0.kp_proc.p_flag & P_WEXIT != 0 } ?? true
  }
}
