import MultishellCore

/// What the app is doing about a worktree's base: its row spins and its menu
/// waits until the step ends.
public enum BaseUpdateStep: Equatable, Sendable {
  /// Putting a stopped merge or rebase back where it began.
  case aborting
  /// Reading for a stop, uncommitted changes and what to ask, before the fetch and after.
  case checking
  /// The base's remote fetched, before anything is written.
  case fetching
  /// The merge or rebase itself.
  case updating(UpdateMethod)

  /// `worktrees show`'s word for it.
  var commandLineName: String {
    switch self {
    case .aborting: "aborting"
    case .checking: "checking"
    case .fetching: "fetching"
    case .updating(.merge): "merging"
    case .updating(.rebase): "rebasing"
    }
  }

  /// The spinner's tooltip.
  public var help: String {
    switch self {
    case .aborting: t("base-update.aborting")
    case .checking: t("base-update.checking")
    case .fetching: t("base-update.fetching")
    case .updating(.merge): t("base-update.merging-from-base")
    case .updating(.rebase): t("base-update.rebasing-onto-base")
    }
  }
}
