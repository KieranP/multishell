import MultishellCore
import MultishellGitKit

extension PresentedError {
  /// A hook, or a file list, around a create or a removal.
  static func hookOrFileListAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as HookFailure:
      // A pre hook's failure stopped the operation, a post hook's came
      // after it. The title says which, and who ended the hook.
      let ending =
        switch failure.stopReason {
        case .none: t("error.hook-failed")
        case .timedOut: t("error.hook-did-not-finish")
        case .byUser: t("error.hook-was-stopped")
        }
      let title =
        switch failure.stage {
        case .preCreate: t("error.pre-create-hook", ending)
        case .postCreate: t("error.post-create-hook", ending)
        case .preDelete: t("error.pre-delete-hook", ending)
        case .postDelete: t("error.post-delete-hook", ending)
        }
      return (title, describe(failure.underlying))
    case let failure as WorktreeFileFailure:
      let title =
        switch failure.placement {
        case .link: t("error.files-not-linked")
        case .copy: t("error.files-not-copied")
        }
      return (
        title, ([failure.description] + describeSkipped(failure.skipped)).joined(separator: "\n\n")
      )
    case let skipped as WorktreeFileSkipped:
      return (t("error.files-skipped-title"), describeSkipped(skipped.entries).joined())
    default:
      return nil
    }
  }

  /// What an entry must be, and the entries that were not; none for none.
  private static func describeSkipped(_ entries: [String]) -> [String] {
    guard !entries.isEmpty else { return [] }
    return [t("error.files-skipped-message", entries.map { "• " + $0 }.joined(separator: "\n"))]
  }
}
