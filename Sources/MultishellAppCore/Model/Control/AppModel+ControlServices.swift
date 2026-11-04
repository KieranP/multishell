import MultishellCore
import MultishellServices

extension AppModel {
  /// A click on the row's pull request or CI glyph, refused where the row
  /// draws none for the page.
  func replyToShowServicePage(_ page: ServicePage, of id: String?) -> ControlReply {
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
    // The panel is the main window's; with it shut nothing would show the page.
    guard isWorkspaceWindowOpen else { return .refused(.noWindow) }
    let services = services(of: shown)
    let hasGlyph =
      switch page {
      case .ciRuns: services.ciRun != nil
      case .pullRequest: services.shownPullRequest != nil
      }
    guard hasGlyph else {
      return .refused(.noServicePage(page, id: ControlID.worktree(shown.id)))
    }
    showFilesPanel(page.filesPanelMode, of: shown)
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
