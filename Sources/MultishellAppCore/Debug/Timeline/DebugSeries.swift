/// One coloured band of a split tile, named in its legend.
public enum DebugSeries: Sendable {
  case app
  case appTerminals
  case childProcesses
  case diskRead
  case diskWritten
  case mainThread
  /// Interrupt wakeups less those that woke the whole package.
  case otherInterruptWakeups
  case otherThreads
  case packageIdleWakeups
  case terminalThreads
}
