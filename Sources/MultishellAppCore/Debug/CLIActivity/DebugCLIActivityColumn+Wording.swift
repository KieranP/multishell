import MultishellCore

extension DebugCLIActivityColumn {
  public var sortTitle: String {
    switch self {
    case .command: t("debug.cli-activity-sort.command")
    case .runs: t("debug.cli-activity-sort.runs")
    case .totalDuration: t("debug.cli-activity-sort.total-duration")
    case .meanDuration: t("debug.cli-activity-sort.mean-duration")
    case .slowestDuration: t("debug.cli-activity-sort.slowest-duration")
    case .meanPeakMemory: t("debug.cli-activity-sort.mean-peak-memory")
    case .peakMemory: t("debug.cli-activity-sort.peak-memory")
    case .slowestLocation: t("debug.cli-activity-sort.slowest-location")
    }
  }
}
