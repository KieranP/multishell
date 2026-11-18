import MultishellCore

extension DebugAppActivityColumn {
  public var sortTitle: String {
    switch self {
    case .bytesWritten: t("debug.app-activity-sort.bytes-written")
    case .count: t("debug.app-activity-sort.count")
    case .meanDuration: t("debug.app-activity-sort.mean-duration")
    case .slowestDuration: t("debug.app-activity-sort.slowest-duration")
    case .totalDuration: t("debug.app-activity-sort.total-duration")
    case .activity: t("debug.app-activity-sort.activity")
    }
  }
}
