import Foundation

@testable import MultishellAppCore

/// A desktop that records what the model asked of it.
@MainActor
final class FakePlatform: Platform {
  var isActive = true
  var onDidBecomeActive: (@MainActor () -> Void)?
  var isWorkspaceWindowKey = true
  var closedKeyWindows = 0
  var directoryToChoose: URL?
  var revealed: [URL] = []
  var clipboard: [String] = []
  var applications: [String: URL] = [:]
  var opened: [(item: URL, application: URL)] = []
  var plainTextEditor: URL?
  var bundledHelper: URL?
  var installedCommandLineTool = false
  var handedOverToRunningInstance = false
  var quitCount = 0
  var isWorkspaceWindowFullScreen = false
  /// Runs inside `quit`, which returning stands for AppKit not ending the app.
  var onQuit: () -> Void = {}
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
  nonisolated private let fakeTrash = FakeTrash()
  /// Every value the badge has been set to, in order, so a test can see it
  /// clear as well as count.
  var badges: [Int?] = []
  var notificationSettingsLocation: String? = "System Settings > Notifications"
  /// What the model asked to be called on each frame; a test calls it.
  var onDisplayFrame: (@MainActor (ContinuousClock.Instant) -> Void)?
  var windows: [PlatformWindow] = []
  var menuItems: [PlatformMenuItem] = []
  var performedMenuItems: [[String]] = []
  var shownWindows: [AuxiliaryWindow] = []
  var closedWindows: [AuxiliaryWindow] = []
  /// `nil` stands for a closed main window.
  var workspaceWindowSize: (width: Double, height: Double)? = (1_200, 800)
  var workspaceWindowScreenshot: Data?
  var signposts: [String] = []
  var fontFamilies: Set<String> = ["Menlo", "SF Mono"]

  func log(_ message: String) { logged.append(message) }

  func closeKeyWindow() { closedKeyWindows += 1 }
  func chooseDirectory(prompt: String) async -> URL? { directoryToChoose }
  func revealInFileBrowser(_ url: URL) { revealed.append(url) }
  func copyToClipboard(_ text: String) { clipboard.append(text) }
  nonisolated func moveToTrash(_ url: URL) throws {
    fakeTrash.onMainThread.append(Thread.isMainThread)
    guard let trash = fakeTrash.destination else { throw TrashRefused() }
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    try FileManager.default.moveItem(
      at: url,
      to: trash.appendingPathComponent(url.lastPathComponent),
    )
    fakeTrash.trashed.append(url)
  }
  func applicationURL(forIdentifier identifier: String) -> URL? { applications[identifier] }
  func open(_ item: URL, withApplication application: URL) async throws {
    opened.append((item, application))
  }
  func plainTextEditorURL() -> URL? { plainTextEditor }
  func installCommandLineTool() throws { installedCommandLineTool = true }
  func handOverToRunningInstance() { handedOverToRunningInstance = true }
  func quit() {
    quitCount += 1
    onQuit()
  }
  func setBadgeCount(_ count: Int?) { badges.append(count) }
  func startDisplayFrameCallbacks(
    _ onFrame: @escaping @MainActor (ContinuousClock.Instant) -> Void
  ) { onDisplayFrame = onFrame }
  func stopDisplayFrameCallbacks() { onDisplayFrame = nil }
  func show(_ window: AuxiliaryWindow) { shownWindows.append(window) }
  func close(_ window: AuxiliaryWindow) { closedWindows.append(window) }
  func resizeWorkspaceWindow(width: Double, height: Double) -> Bool {
    guard workspaceWindowSize != nil else { return false }
    workspaceWindowSize = (width, height)
    return true
  }
  func setWorkspaceWindowFullScreen(_ isOn: Bool) -> Bool {
    guard workspaceWindowSize != nil else { return false }
    isWorkspaceWindowFullScreen = isOn
    return true
  }
  func screenshotWorkspaceWindow() -> Data? { workspaceWindowScreenshot }
  func signpost(_ name: String) { signposts.append(name) }
  func hasFontFamily(_ family: String) -> Bool { fontFamilies.contains(family) }
  func performMenuItem(_ path: [String]) -> PlatformMenuOutcome {
    guard let item = menuItems.first(where: { $0.path == path }) else { return .notFound }
    guard item.isEnabled else { return .disabled }
    performedMenuItems.append(path)
    return .performed
  }
}
