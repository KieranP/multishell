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
  // swiftlint:disable:next cyclomatic_complexity
  private func reply(to request: ControlRequest) async -> ControlReply {
    switch request {
    case .info: answerInfo()
    case .quit(let force): answerQuit(force: force)
    case .readGlobalSettings(let key): answerReadGlobalSettings(key: key)
    case .writeGlobalSetting(let key, let value): answerWriteGlobalSetting(key, value)

    case .readProjectSettings(let project, let key):
      answerReadProjectSettings(of: project, key: key)

    case .writeProjectSetting(let project, let key, let value):
      answerWriteProjectSetting(of: project, key, value)

    case .listProjects: answerListProjects()
    case .addProject(let path): await answerAddProject(at: path)
    case .removeProject(let id, let force): answerRemoveProject(id, force: force)
    case .listWorktrees(let project): answerListWorktrees(of: project)
    case .newWorktree(let order): await answerNewWorktree(order)
    case .removeWorktree(let order): await answerRemoveWorktree(order)
    case .selectWorktree(let id): answerSelectWorktree(id)
    case .listTabs(let worktree): answerListTabs(of: worktree)
    case .newTab(let order): answerNewTab(order)
    case .selectTab(let id): answerSelectTab(id)
    case .closeTab(let id, let force): answerCloseTab(id, force: force)

    case .moveTab(let id, let before, let anchor):
      answerMoveTab(id, before: before, anchor: anchor)

    case .renameTab(let id, let title): answerRenameTab(id, to: title)
    case .splitPane(let axis, let tab): answerSplitPane(axis, inTab: tab)
    case .selectPane(let id): answerSelectPane(id)
    case .closePane(let id, let force): answerClosePane(id, force: force)

    case .typeIntoPane(let id, let text, let pressingReturn):
      answerTypeIntoPane(text, pressingReturn: pressingReturn, into: id)

    case .describePane(let id): answerDescribePane(id)
    case .describeTab(let id): answerDescribeTab(id)
    case .describeWorktree(let id): await answerDescribeWorktree(id)
    case .renameWorktree(let id, let name): answerRenameWorktree(id, to: name)
    case .listSidebar: answerListSidebar()
    case .pasteIntoPane(let id, let text): answerPasteIntoPane(text, into: id)
    case .pressKeys(let id, let keys): answerPressKeys(keys, in: id)
    case .findInPane(let id, let action): answerFindInPane(action, in: id)
    case .listBoard: answerListBoard()
    case .listMenuItems: answerListMenuItems()
    case .performMenuItem(let path): answerPerformMenuItem(path)
    case .debugNotifications: answerDebugNotifications()
    case .debugSummary(let last): answerDebugSummary(last: last)

    case .readPane(let id, let includingScrollback):
      answerReadPane(id, includingScrollback: includingScrollback)

    case .reportPaneState(let report): answerReportPaneState(report)
    case .dismissPresentation: answerDismissPresentation()
    case .showView(let view, let project): answerShowView(view, project: project)
    case .hideView(let view): answerHideView(view)
    case .filterSidebar(let text): answerFilterSidebar(text)
    case .resizeWindow(let width, let height): answerResizeWindow(width: width, height: height)
    case .setDebugTools(let enabled): answerSetDebugTools(enabled)
    case .setFullScreen(let on): answerSetFullScreen(on)
    case .setDebugInfo(let shown): answerSetDebugInfo(shown)
    case .debugSamples(let last): answerDebugSamples(last: last)
    case .debugMemory: answerDebugMemory()
    case .markDebugSample(let name): answerMarkDebugSample(name)
    case .debugGitRuns(let last): answerDebugGitRuns(last: last)
    case .screenshot(let pane): answerScreenshot(pane: pane)
    }
  }
}
