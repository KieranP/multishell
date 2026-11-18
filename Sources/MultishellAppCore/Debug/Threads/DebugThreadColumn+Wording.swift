import MultishellCore

extension DebugThreadColumn {
  public var sortTitle: String {
    switch self {
    case .cpuTime: t("debug.thread-sort.cpu-time")
    case .meanPercent: t("debug.thread-sort.mean-percent")
    case .thread: t("debug.thread-sort.thread")
    case .threadCount: t("debug.thread-sort.thread-count")
    }
  }
}
