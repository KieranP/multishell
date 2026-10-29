import MultishellCore
import MultishellServices

extension AppModel {
  /// A click on the row's pull request and CI glyphs, its project opened and
  /// the filter cleared where they hide the row, as a selection does.
  func replyToShowServices(of id: String?) -> ControlReply {
    // Drawn over the main window's row alone; with it shut nothing would show it.
    guard platform.isWorkspaceWindowVisible else { return .refused(.noWindow) }
    let shown: Worktree
    if let id {
      guard let worktree = worktree(withControlID: id) else {
        return .refused(.noWorktree(id: id))
      }
      shown = worktree
    } else {
      guard let worktree = worktreeInView else { return .refused(.nothingInView) }
      shown = worktree
    }
    guard services(of: shown).showsAnything else {
      return .refused(.noServices(id: ControlID.worktree(shown.id)))
    }
    expandProject(holding: shown)
    setShowsServicesPopover(true, of: shown.id)
    return .done
  }

  /// Answered once every project has been read through the stand-in, or the tools.
  func replyToStandInServices(_ json: String?) async -> ControlReply {
    guard let json else {
      await standInServices(nil)
      return .done
    }
    let standIn: ServiceStandIn
    do {
      standIn = try ServiceStandIn(json: json)
    } catch {
      return .refused(.serviceStandInUnreadable(reason: error.reason))
    }
    await standInServices(standIn)
    return .done
  }
}
