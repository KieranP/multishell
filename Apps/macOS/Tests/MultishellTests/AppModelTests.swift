import AppKit
import MultishellCore
import Testing

@testable import Multishell

/// A watcher that records what it was asked to watch and can be poked.
@MainActor
private final class FakeWatcher: DirectoryWatcher {
  var onChange: (@MainActor () -> Void)?
  var watched: [URL] = []
  var stopped = false
  func watch(_ directories: [URL]) { watched = directories }
  func stop() { stopped = true }
}

/// An engine that opens everything and remembers focus and closes.
@MainActor
private final class FakeEngine: TerminalSurfaceHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var focused: [TerminalSession.ID] = []
  var closed: [TerminalSession.ID] = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws { openSessionIDs.insert(session.id) }
  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    closed.append(id)
  }
  func focus(_ id: TerminalSession.ID) { focused.append(id) }
  func view(for id: TerminalSession.ID) -> NSView? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}

@MainActor
private struct Harness {
  let model: AppModel
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let project: Project
  let main: Worktree
  let feature: Worktree

  init(savedSelection: Bool = false) {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-appmodel-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: tmp.appendingPathComponent("state.json")))
    project = store.addProject(at: tmp)  // exists on disk, so `select` accepts it
    main = Worktree(path: tmp, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    feature = Worktree(
      path: tmp.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    try? FileManager.default.createDirectory(at: feature.path, withIntermediateDirectories: true)
    store.replaceWorktrees([main, feature], forProject: project.id)
    if savedSelection { store.selectWorktree(main.id) }

    let engine = self.engine
    let host = MultiEngineHost(engine: .ghostty) { _ in engine }
    model = AppModel(store: store, host: host, worktrees: nil, watcher: watcher)
  }
}

@Suite @MainActor
struct AppModelTests {
  @Test func launchStartsWithNothingSelectedAndNoShells() {
    let h = Harness(savedSelection: true)
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.liveTerminalCount == 0)
    #expect(
      h.model.presentedError?.title == "git not found", "no git was injected, and that is reported")
  }

  @Test func selectingAWorktreeOpensATabAndWarmsIt() {
    let h = Harness()
    h.model.select(h.main)

    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.focused.count == 1)
    #expect(h.model.liveSessions == h.engine.openSessionIDs)
  }

  @Test func savedTabsInAnUnvisitedWorktreeStayCold() {
    let h = Harness()
    h.store.openTab(in: h.feature.id)
    h.store.openTab(in: h.feature.id)
    h.model.select(h.main)

    #expect(h.model.workspace.sessions.count == 3)
    #expect(h.model.liveTerminalCount == 1, "only the selected worktree's shell is live")

    h.model.select(h.feature)
    #expect(h.model.liveTerminalCount == 3, "visiting warms the saved tabs, and main stays warm")
  }

  @Test func selectingAWorktreeWhoseDirectoryIsGoneIsRefused() {
    let h = Harness()
    let ghost = Worktree(
      path: URL(fileURLWithPath: "/nowhere/\(UUID().uuidString)"), projectID: h.project.id,
      head: "c", branch: "ghost")
    h.store.replaceWorktrees([h.main, h.feature, ghost], forProject: h.project.id)
    h.model.presentedError = nil

    h.model.select(ghost)

    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func closingTheLastPaneClosesItsTabAndShell() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 2)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.engine.closed.count == 1)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)

    h.model.closeActivePane()  // nothing left: must not throw or select anything
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }

  @Test func splitThenCloseCollapsesBackToOnePane() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.isSplit && h.model.liveTerminalCount == 2)

    h.model.closeActivePane()
    let after = h.model.workspace.tab(tab.id)!
    #expect(!after.isSplit)
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func removalAsksUnlessTheProjectOptedOut() {
    let h = Harness()
    h.model.requestRemoval(of: h.feature)
    #expect(h.model.pendingRemoval?.id == h.feature.id)

    h.model.pendingRemoval = nil
    h.model.updateSettings(ProjectSettings(confirmsWorktreeRemoval: false), for: h.project)
    h.model.requestRemoval(of: h.feature)
    #expect(
      h.model.pendingRemoval == nil, "goes straight to removal, which needs git and so no-ops here")
  }

  @Test func activityInABackgroundTabIsRememberedUntilItIsShown() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: second.focusedSessionID)

    #expect(h.model.hasUnseenActivity(first))
    #expect(!h.model.hasUnseenActivity(second), "the focused tab is being watched")
    #expect(h.model.unseenActivityCount(in: h.main.id) == 1)

    h.model.activate(first)
    #expect(!h.model.hasUnseenActivity(first))
  }

  @Test func aProcessExitDropsTheTabAndTheLiveCount() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID, code: 0)

    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func switchingEngineAffectsOnlyNewTabs() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setTerminalEngine(.swiftTerm)
    #expect(h.model.workspace.terminalEngine == .swiftTerm)
    #expect(h.model.host.engine == .swiftTerm)
    #expect(h.model.liveTerminalCount == 1, "the running shell was not restarted")
  }

  @Test func activeProjectFollowsSelectionOrTheOnlyProject() {
    let h = Harness()
    #expect(h.model.activeProject?.id == h.project.id, "one project, nothing selected")
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(h.model.activeProject == nil, "two projects, nothing selected")
    h.model.select(h.feature)
    #expect(h.model.activeProject?.id == h.project.id)
  }

  @Test func tabRenamesAndReordersReachTheStore() {
    let h = Harness()
    h.model.select(h.main)
    let a = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let b = h.model.workspace.activeTab(in: h.main.id)!

    h.model.renameTab(a.id, to: "build")
    h.model.moveTab(b.id, before: a.id)

    #expect(h.model.workspace.title(of: h.model.workspace.tab(a.id)!) == "build")
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [b.id, a.id])
  }
}
