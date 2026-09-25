import Foundation
import Synchronization
import TestScratch

@testable import MultishellAppCore

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
    get { fakeTrash.destination }
    set { fakeTrash.destination = newValue }
  }
  var trashed: [URL] { fakeTrash.trashed }
  /// Per call, whether it came on the main thread, which it must not.
  var trashCallsOnMainThread: [Bool] { fakeTrash.onMainThread }
  private nonisolated let fakeTrash = FakeTrash()

  func closeKeyWindow() { closedKeyWindows += 1 }
  func chooseDirectory(prompt: String) async -> URL? { directoryToChoose }
  func revealInFileBrowser(_ url: URL) { revealed.append(url) }
  func copyToClipboard(_ text: String) { clipboard.append(text) }
  nonisolated func moveToTrash(_ url: URL) throws {
    fakeTrash.onMainThread.append(Thread.isMainThread)
    guard let trash = fakeTrash.destination else { throw TrashRefused() }
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    try FileManager.default.moveItem(
      at: url, to: trash.appendingPathComponent(url.lastPathComponent))
    fakeTrash.trashed.append(url)
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

private struct TrashRefused: Error {}

/// What the fake Trash was asked, written from whatever thread asked.
private final class FakeTrash: Sendable {
  private struct State {
    var destination: URL? = Scratch.path("trash")
    var trashed: [URL] = []
    var onMainThread: [Bool] = []
  }

  private let state = Mutex(State())

  deinit {
    if let destination { Scratch.remove(destination) }
  }

  var destination: URL? {
    get { state.withLock { $0.destination } }
    set { state.withLock { $0.destination = newValue } }
  }
  var trashed: [URL] {
    get { state.withLock { $0.trashed } }
    set { state.withLock { $0.trashed = newValue } }
  }
  var onMainThread: [Bool] {
    get { state.withLock { $0.onMainThread } }
    set { state.withLock { $0.onMainThread = newValue } }
  }
}
