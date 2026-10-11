import Foundation

/// A desktop with nothing on it: for tests, and for a headless run.
@MainActor
public final class NullPlatform: Platform {
  public var onDidBecomeActive: (@MainActor () -> Void)?
  public var isActive: Bool { true }
  public var workspaceWindowIsKey: Bool { true }
  public var bundledHelper: URL? { nil }
  public var notificationSettingsLocation: String? { nil }
  public var windows: [PlatformWindow] { [] }
  public var menuItems: [PlatformMenuItem] { [] }
  public var isWorkspaceWindowFullScreen: Bool { false }

  public init() {}

  public func closeKeyWindow() {}
  public func chooseDirectory(prompt: String) async -> URL? { nil }
  public func revealInFileBrowser(_ url: URL) {}
  public func copyToClipboard(_ text: String) {}
  /// No Trash here, so the directory is deleted.
  nonisolated public func moveToTrash(_ url: URL) throws {
    try FileManager.default.removeItem(at: url)
  }
  public func applicationURL(forIdentifier identifier: String) -> URL? { nil }
  public func open(_ directory: URL, withApplication application: URL) async throws {}
  public func installCommandLineTool() throws {}
  public func setBadgeCount(_ count: Int?) {}
  public func log(_ message: String) {}
  public func handOverToRunningInstance() {}
  public func quit() {}
  public func startDisplayFrameCallbacks(
    _ onFrame: @escaping @MainActor (ContinuousClock.Instant) -> Void
  ) {}
  public func stopDisplayFrameCallbacks() {}
  public func show(_ window: AuxiliaryWindow) {}
  public func close(_ window: AuxiliaryWindow) {}
  public func resizeWorkspaceWindow(width: Double, height: Double) -> Bool { false }
  public func setWorkspaceWindowFullScreen(_ isOn: Bool) -> Bool { false }
  public func screenshotWorkspaceWindow() -> Data? { nil }
  public func signpost(_ name: String) {}
  public func performMenuItem(_ path: [String]) -> PlatformMenuOutcome { .notFound }
  public func hasFontFamily(_ family: String) -> Bool { false }
}
