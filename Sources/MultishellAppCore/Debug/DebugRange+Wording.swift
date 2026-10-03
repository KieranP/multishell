import MultishellCore

extension DebugRange {
  public var title: String {
    switch self {
    case .oneMinute: t("debug.range.one-minute")
    case .fiveMinutes: t("debug.range.five-minutes")
    case .fifteenMinutes: t("debug.range.fifteen-minutes")
    }
  }

  /// The left end of the axis.
  public var agoTitle: String {
    switch self {
    case .oneMinute: t("debug.range.one-minute-ago")
    case .fiveMinutes: t("debug.range.five-minutes-ago")
    case .fifteenMinutes: t("debug.range.fifteen-minutes-ago")
    }
  }
}
