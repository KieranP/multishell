import MultishellCore
import MultishellProcess

extension MemoryPressureLevel {
  /// As the Memory Pressure tile reads it.
  var title: String {
    switch self {
    case .normal: t("debug.pressure.normal")
    case .warning: t("debug.pressure.warning")
    case .critical: t("debug.pressure.critical")
    }
  }
}
