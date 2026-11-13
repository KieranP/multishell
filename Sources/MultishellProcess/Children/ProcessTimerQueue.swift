import Dispatch

/// Where a run's timers and completion go. A queue of its own gets a thread when
/// reads blocked on a dead mount hold every one the global queues run on.
enum ProcessTimerQueue {
  static let shared = DispatchQueue(label: "multishell.process-timers")
}
