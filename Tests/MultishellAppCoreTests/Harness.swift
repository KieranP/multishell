import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

/// A watcher that records what it was asked to watch and can be poked.
@MainActor
final class FakeWatcher: DirectoryWatcher {
  var onChange: (@MainActor ([URL]) -> Void)?
  var watched: [URL] = []
  var stopped = false
  func watch(_ directories: [URL]) { watched = directories }
  func stop() { stopped = true }
}

/// An engine that opens everything and remembers focus and closes.
@MainActor
final class FakeEngine: TerminalSurfaceHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var focused: [TerminalSession.ID] = []
  var closed: [TerminalSession.ID] = []
  /// What was pasted into each session, in order.
  var pasted: [(id: TerminalSession.ID, text: String)] = []
  /// Every search step, in order, whichever pane it was for.
  var searched: [(id: TerminalSession.ID, command: TerminalSearch)] = []
  /// What the registry asked for, command line included.
  var opened: [TerminalSession] = []
  weak var delegate: (any TerminalHostDelegate)?
  /// Every open throws, standing in for a machine out of descriptors.
  var refusesToOpen = false
  func open(_ session: TerminalSession) throws {
    if refusesToOpen { throw OpenRefused() }
    openSessionIDs.insert(session.id)
    opened.append(session)
  }
  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    closed.append(id)
  }
  func focus(_ id: TerminalSession.ID) { focused.append(id) }
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard openSessionIDs.contains(id) else { return false }
    pasted.append((id, text))
    return true
  }
  func search(_ command: TerminalSearch, in id: TerminalSession.ID) -> Bool {
    guard openSessionIDs.contains(id) else { return false }
    searched.append((id, command))
    return true
  }
  func view(for id: TerminalSession.ID) -> FakeSurface? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}

/// A channel the test drives by hand.
@MainActor
final class FakeStateSource: SessionStateSource {
  var onReport: (@MainActor (SessionStateReport) -> Void)?
  var started = false
  /// Thrown by `start`, standing in for a socket another copy holds.
  var startError: (any Error)?
  func start() throws {
    if let startError { throw startError }
    started = true
  }
  func stop() { started = false }
  func send(_ report: SessionStateReport) { onReport?(report) }
}

@MainActor
final class FakeNotifier: SessionNotifier {
  var onActivate: (@MainActor (SessionStates.Key) -> Void)?
  var posted: [(title: String, body: String, key: SessionStates.Key)] = []
  /// What the system would answer, and how often it was asked.
  var answer = NotificationAuthorization.allowed
  var authorizationRequests = 0
  /// Keys whose banner was taken back, in the order they were.
  var withdrawn: [SessionStates.Key] = []
  func notify(title: String, body: String, about key: SessionStates.Key) {
    posted.append((title, body, key))
  }
  func withdraw(about key: SessionStates.Key) {
    withdrawn.append(key)
  }
  func authorization() async -> NotificationAuthorization { answer }
  func requestAuthorization() async -> NotificationAuthorization {
    authorizationRequests += 1
    return answer
  }
}

struct TrashRefused: Error {}

struct OpenRefused: Error {}

/// Stands in for the platform's view type; the model never looks inside.
final class FakeSurface {}

/// A desktop that records what the model asked of it.
@MainActor
final class FakePlatform: Platform {
  var isActive = true
  var onDidBecomeActive: (@MainActor () -> Void)?
  var workspaceWindowIsKey = true
  var closedKeyWindows = 0
  var directoryToChoose: URL?
  var revealed: [URL] = []
  var clipboard: [String] = []
  var applications: [String: URL] = [:]
  var opened: [(directory: URL, application: URL)] = []
  var bundledHelper: URL?
  var installedCommandLineTool = false
  var handedOverToRunningInstance = false
  var logged: [String] = []
  /// Where `moveToTrash` puts things, standing in for the Trash; `nil`
  /// makes it refuse.
  var trash: URL? {
    get { trashRecord.destination }
    set { trashRecord.destination = newValue }
  }
  var trashed: [URL] { trashRecord.trashed }
  /// Per call, whether it came on the main thread, which it must not.
  var trashCallsOnMainThread: [Bool] { trashRecord.onMainThread }
  nonisolated let trashRecord = TrashRecord()

  func closeKeyWindow() { closedKeyWindows += 1 }
  func chooseDirectory(prompt: String) async -> URL? { directoryToChoose }
  func revealInFileBrowser(_ url: URL) { revealed.append(url) }
  func copyToClipboard(_ text: String) { clipboard.append(text) }
  nonisolated func moveToTrash(_ url: URL) throws {
    trashRecord.onMainThread.append(Thread.isMainThread)
    guard let trash = trashRecord.destination else { throw TrashRefused() }
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    try FileManager.default.moveItem(
      at: url, to: trash.appendingPathComponent(url.lastPathComponent))
    trashRecord.trashed.append(url)
  }
  func applicationURL(forIdentifier identifier: String) -> URL? { applications[identifier] }
  func open(_ directory: URL, withApplication application: URL) async throws {
    opened.append((directory, application))
  }
  func installCommandLineTool() throws { installedCommandLineTool = true }
  func handOverToRunningInstance() { handedOverToRunningInstance = true }
  /// Every value the badge has been set to, in order, so a test can see it
  /// clear as well as count.
  var badges: [Int?] = []
  func setBadgeCount(_ count: Int?) { badges.append(count) }
  var notificationSettingsLocation: String? = "System Settings > Notifications"
  func log(_ message: String) { logged.append(message) }
}

/// What the fake Trash was asked, written from whatever thread asked.
final class TrashRecord: @unchecked Sendable {
  private let lock = NSLock()
  private var _destination: URL? = Scratch.path("trash")
  private var _trashed: [URL] = []
  private var _onMainThread: [Bool] = []

  deinit {
    if let _destination { Scratch.remove(_destination) }
  }

  var destination: URL? {
    get { lock.withLock { _destination } }
    set { lock.withLock { _destination = newValue } }
  }
  var trashed: [URL] {
    get { lock.withLock { _trashed } }
    set { lock.withLock { _trashed = newValue } }
  }
  var onMainThread: [Bool] {
    get { lock.withLock { _onMainThread } }
    set { lock.withLock { _onMainThread = newValue } }
  }
}

@MainActor
final class Harness {
  let model: AppModel<FakeSurface>
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let source = FakeStateSource()
  let notifier = FakeNotifier()
  let platform = FakePlatform()
  let project: Project
  let main: Worktree
  let feature: Worktree
  let root: URL

  init(savedSelection: Bool = false, stateFile: URL? = nil) {
    let tmp = Scratch.path("appmodel")
    root = tmp
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(
        fileURL: stateFile ?? tmp.appendingPathComponent("state.json")))
    project = store.addProject(at: tmp)  // exists on disk, so `select` accepts it
    main = Worktree(path: tmp, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    feature = Worktree(
      path: tmp.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    try? FileManager.default.createDirectory(at: feature.path, withIntermediateDirectories: true)
    store.replaceWorktrees([main, feature], forProject: project.id)
    if savedSelection { store.selectWorktree(main.id) }

    model = AppModel(
      store: store, host: engine, worktrees: nil, watcher: watcher, platform: platform,
      stateSource: source, notifier: notifier)
    model.statusReads.pace = .unpaced
    let path = tmp.appendingPathComponent("bin").path
    model.captureLoginEnvironment = {
      LoginShellEnvironment(
        variables: ["PATH": path, "HOME": tmp.path],
        source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    }
  }

  /// A test's own agent on a PATH nothing else has, so detection reads the
  /// scratch directory and not the machine.
  func installFakeAgent(_ name: String) throws {
    let bin = root.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try Scratch.script("exit 0", at: bin.appendingPathComponent(name))
  }

  deinit { Scratch.remove(root) }

  /// Lets the model's own tasks finish. They are `@MainActor`, so yielding
  /// hands them the actor this test holds; a handful of turns covers one
  /// that awaits a port on the way.
  func settled(turns: Int = 10) async {
    for _ in 0..<turns { await Task.yield() }
  }

  /// The alert a save that ran off the main actor raised, waiting up to a
  /// second for the write to come back; `nil` where none did.
  func presentedErrorArrives() async -> PresentedError? {
    for _ in 0..<100 where model.presentedError == nil {
      try? await Task.sleep(for: .milliseconds(10))
    }
    return model.presentedError
  }
}
