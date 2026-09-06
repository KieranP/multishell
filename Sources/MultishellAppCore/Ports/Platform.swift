import Foundation

/// What the model needs from the desktop it runs on, and nothing more.
///
/// Each GUI implements this once: AppKit on the Mac, GTK or Qt on Linux.
/// The model never names a window, a pasteboard or a workspace API, so it
/// compiles and is tested without any of them.
@MainActor
public protocol Platform: AnyObject {
  /// Whether the app is frontmost. Status polling pauses while it is not,
  /// and a report about the shown tab still earns a banner then.
  var isActive: Bool { get }
  /// Called when the app comes back to the front, so stale badges refresh.
  var onDidBecomeActive: (@MainActor () -> Void)? { get set }
  /// Whether a keyboard command should act on the workspace. In any other
  /// window (Settings, Project Settings) Cmd+W must close that window
  /// instead of a pane the user cannot see.
  var workspaceWindowIsKey: Bool { get }
  func closeKeyWindow()

  /// A directory picker, or `nil` when the user cancels.
  func chooseDirectory(prompt: String) async -> URL?
  /// Shows the file in the platform's file browser.
  func revealInFileBrowser(_ url: URL)
  func copyToClipboard(_ text: String)

  /// Moves a removed worktree's directory to the platform's Trash, where
  /// the user can get it back. Throws when it will not take it; the model
  /// then deletes the directory instead. A platform with no Trash deletes
  /// outright, as `NullPlatform` does.
  func moveToTrash(_ url: URL) throws

  /// Where an installed application lives, by the identifier in
  /// `EditorDescriptor.bundleIdentifier`, or `nil` when the platform has
  /// no such lookup or the application is absent.
  func applicationURL(forIdentifier identifier: String) -> URL?
  /// Hands a directory to an application found by `applicationURL`.
  func open(_ directory: URL, withApplication application: URL) async throws

  /// The helper binary shipped with this build, or `nil` outside a bundle.
  /// `HelperLink` points the stable link at it on launch.
  var bundledHelper: URL? { get }
  /// Links the helper somewhere on the default PATH, behind whatever
  /// privilege prompt the platform needs.
  func installCommandLineTool() throws

  /// A line for the platform's log, for what is worth a note but not an
  /// alert.
  func log(_ message: String)
}

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
  public func moveToTrash(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
  public func applicationURL(forIdentifier identifier: String) -> URL? { nil }
  public func open(_ directory: URL, withApplication application: URL) async throws {}
  public var bundledHelper: URL? { nil }
  public func installCommandLineTool() throws {}
  public func log(_ message: String) {}
}
