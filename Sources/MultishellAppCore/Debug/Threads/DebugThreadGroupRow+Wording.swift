import MultishellCore

extension DebugThreadGroupRow {
  public var title: String {
    switch group {
    case .main: t("debug.thread.main")
    case .terminals: t("debug.thread-group.terminals")
    case .other: t("debug.thread-group.other")
    }
  }
}
