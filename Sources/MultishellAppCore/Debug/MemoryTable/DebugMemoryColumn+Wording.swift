import MultishellCore

extension DebugMemoryColumn {
  public var sortTitle: String {
    switch self {
    case .name: t("debug.memory-sort.name")
    case .processCount: t("debug.memory-sort.process-count")
    case .selfMemory: t("debug.memory-sort.self-memory")
    case .totalMemory: t("debug.memory-sort.total-memory")
    case .worktree: t("debug.memory-sort.worktree")
    }
  }
}
