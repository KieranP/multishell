import Foundation
import MultishellCore

extension AppModel {
  /// A request from the command line, done as the menu item or click it
  /// stands for would do it; see Docs/design/agents.md.
  func answer(_ request: ControlRequest) async -> ControlReply {
    let requestID = UUID()
    requestsBeingAnswered.insert(requestID)
    let controlReply = await ControlRequestScope.$id.withValue(requestID) {
      await reply(to: request)
    }
    return finishAnswering(requestID, with: controlReply)
  }

  // One case a request, exhaustive so a new one cannot go unanswered.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func reply(to request: ControlRequest) async -> ControlReply {
    switch request {
    case .info: replyToInfo()
    case .quit(let force): replyToQuit(force: force)
    case .readGlobalSettings(let key): replyToReadGlobalSettings(key: key)
    case .writeGlobalSetting(let key, let value): replyToWriteGlobalSetting(key, value)

    case .readProjectSettings(let project, let key):
      replyToReadProjectSettings(of: project, key: key)

    case .writeProjectSetting(let project, let key, let value):
      replyToWriteProjectSetting(of: project, key, value)

    case .listProjects: replyToListProjects()
    case .addProject(let path): await replyToAddProject(at: path)
    case .removeProject(let id, let force): replyToRemoveProject(id, force: force)
    case .listWorktrees(let project): replyToListWorktrees(of: project)
    case .newWorktree(let order): await replyToNewWorktree(order)
    case .removeWorktree(let order): await replyToRemoveWorktree(order)
    case .selectWorktree(let id): replyToSelectWorktree(id)
    case .listTabs(let worktree): replyToListTabs(of: worktree)
    case .newTab(let order): replyToNewTab(order)
    case .selectTab(let id): replyToSelectTab(id)
    case .closeTab(let id, let force): replyToCloseTab(id, force: force)

    case .moveTab(let id, let placement, let anchor):
      replyToMoveTab(id, placement, anchor: anchor)

    case .renameTab(let id, let title): replyToRenameTab(id, to: title)
    case .splitPane(let axis, let tab): replyToSplitPane(axis, inTab: tab)
    case .selectPane(let id): replyToSelectPane(id)
    case .closePane(let id, let force): replyToClosePane(id, force: force)

    case .typeIntoPane(let id, let text, let pressingReturn):
      replyToTypeIntoPane(text, pressingReturn: pressingReturn, into: id)

    case .describePane(let id): replyToDescribePane(id)
    case .describeTab(let id): replyToDescribeTab(id)
    case .describeWorktree(let id): await replyToDescribeWorktree(id)
    case .renameWorktree(let id, let name): replyToRenameWorktree(id, to: name)
    case .listSidebar: replyToListSidebar()
    case .pasteIntoPane(let id, let text): replyToPasteIntoPane(text, into: id)
    case .pressKeys(let id, let keys): replyToPressKeys(keys, in: id)
    case .findInPane(let id, let action): replyToFindInPane(action, in: id)
    case .listBoard: replyToListBoard()
    case .listMenuItems: replyToListMenuItems()
    case .performMenuItem(let path): replyToPerformMenuItem(path)
    case .debugNotifications: replyToDebugNotifications()
    case .debugSummary(let last): replyToDebugSummary(last: last)

    case .readPane(let id, let includingScrollback):
      replyToReadPane(id, includingScrollback: includingScrollback)

    case .reportPaneState(let report): replyToReportPaneState(report)
    case .dismissPresentation: replyToDismissPresentation()
    case .showView(let view, let project): replyToShowView(view, project: project)
    case .hideView(let view): replyToHideView(view)
    case .filterSidebar(let text): replyToFilterSidebar(text)
    case .resizeWindow(let width, let height): replyToResizeWindow(width: width, height: height)
    case .setDebugTools(let enabled): replyToSetDebugTools(enabled)
    case .setFullScreen(let on): replyToSetFullScreen(on)
    case .setDebugInfo(let shown): replyToSetDebugInfo(shown)
    case .debugSamples(let last): replyToDebugSamples(last: last)
    case .debugMemory: replyToDebugMemory()
    case .markDebugSample(let name): replyToMarkDebugSample(name)
    case .debugGitRuns(let last): replyToDebugGitRuns(last: last)
    case .screenshot(let pane): replyToScreenshot(pane: pane)
    case .openFileTab(let worktree, let path): await replyToOpenFileTab(path, in: worktree)
    case .stepToChange(let tab, let direction): replyToStepToChange(direction, in: tab)
    case .findInFileTab(let id, let action): await replyToFindInFileTab(action, in: id)
    case .listFiles: replyToListFiles()
    case .filterFiles(let text): replyToFilterFiles(text)

    case .setFilesFolderExpanded(let path, let expanded):
      replyToSetFilesFolderExpanded(path, expanded: expanded)

    case .setProjectExpanded(let id, let expanded):
      replyToSetProjectExpanded(id, expanded: expanded)

    case .moveProject(let id, let placement, let anchor):
      replyToMoveProject(id, placement, anchor: anchor)

    case .refreshProject(let id): await replyToRefreshProject(id)
    case .fetchProject(let id): await replyToFetchProject(id)
    case .autoRenameWorktree(let id): replyToAutoRenameWorktree(id)
    case .clearPaneState(let id): replyToClearPaneState(id)
    case .clearTabState(let id): replyToClearTabState(id)
    case .clearWorktreeState(let id): replyToClearWorktreeState(id)
    case .moveTabToWorktree(let id, let worktree): replyToMoveTabToWorktree(id, to: worktree)
    case .moveTabToNewGroup(let id): replyToMoveTabToNewGroup(id)

    case .resizeSplit(let tab, let path, let shares):
      replyToResizeSplit(shares, at: path, ofTab: tab)

    case .resizeGroups(let worktree, let shares): replyToResizeGroups(shares, in: worktree)
    case .setPanelWidth(let panel, let width): replyToSetPanelWidth(panel, to: width)
    case .showServices(let worktree): replyToShowServices(of: worktree)
    case .standInServices(let json): await replyToStandInServices(json)
    case .quickSwitcher(let order): await replyToQuickSwitcher(order)
    }
  }
}
