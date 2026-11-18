import MultishellCore

extension DebugSeries {
  /// Its name in the tile's legend, so no band is told by colour alone.
  public var title: String {
    switch self {
    case .app: t("debug.series.app")
    case .appTerminals: t("debug.series.terminals")
    case .terminalThreads: t("debug.series.terminal-threads")
    case .childProcesses: t("debug.series.child-processes")
    case .mainThread: t("debug.series.main-thread")
    case .otherThreads: t("debug.series.other-threads")
    case .diskRead: t("debug.series.disk-read")
    case .diskWritten: t("debug.series.disk-written")
    case .otherInterruptWakeups: t("debug.series.other-interrupt-wakeups")
    case .packageIdleWakeups: t("debug.series.package-idle-wakeups")
    }
  }
}
