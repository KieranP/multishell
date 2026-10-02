import Synchronization

private let nextDeadPID = Atomic<Int32>(100_000)

/// A pid past macOS's PID_MAX of 99999, which no process holds. A reaped child's pid
/// can go to another test's child meanwhile; this cannot. Each call gives a new one.
func deadPID() -> Int32 {
  nextDeadPID.add(1, ordering: .relaxed).oldValue
}
