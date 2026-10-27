import MultishellAppCore
import MultishellCore

extension QuickSwitcherSection.Kind {
  var title: String {
    switch self {
    case .waiting: t("quick-switcher.section.waiting")
    case .recent: t("quick-switcher.section.recent")
    case .places: t("quick-switcher.section.places")
    case .files(let worktreeName): t("quick-switcher.section.files", worktreeName)
    case .changedFiles(let worktreeName): t("quick-switcher.section.changed-files", worktreeName)
    case .commands: t("quick-switcher.section.commands")
    case .worktrees: t("quick-switcher.section.worktrees")
    case .tabs: t("quick-switcher.section.tabs")
    case .agents(let state): state.displayName
    }
  }
}
