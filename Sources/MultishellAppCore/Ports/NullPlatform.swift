import Foundation

/// A desktop with nothing on it: for tests, and for a headless run.
@MainActor
public final class NullPlatform: Platform {
  public var onDidBecomeActive: (@MainActor () -> Void)?
  public init() {}
  public var isActive: Bool { true }
  public var workspaceWindowIsKey: Bool { true }
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
  public var bundledHelper: URL? { nil }
  public func installCommandLineTool() throws {}
  public func setBadgeCount(_ count: Int?) {}
  public var notificationSettingsLocation: String? { nil }
  public func log(_ message: String) {}
  public func handOverToRunningInstance() {}
}
