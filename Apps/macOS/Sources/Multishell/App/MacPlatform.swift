import AppKit
import MultishellAppCore
import MultishellCore
import os

/// `Platform` on AppKit: the one place the model's needs meet the Mac.
@MainActor
final class MacPlatform: Platform {
  /// The workspace window, so window-scoped commands can tell whether they
  /// were issued there or in a settings window. Set by `WindowAccessor`.
  weak var mainWindow: NSWindow?
  var onDidBecomeActive: (@MainActor () -> Void)?

  /// The bundle identifier `make-app.sh` writes, which is what
  /// `log show --predicate 'subsystem == "io.multishell.app"'` matches on.
  /// Named rather than left a literal so a test can hold the two together.
  nonisolated static let loggingSubsystem = "io.multishell.app"

  private let logger = Logger(subsystem: loggingSubsystem, category: "platform")

  init() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.onDidBecomeActive?() }
    }
  }

  var isActive: Bool { NSApp?.isActive ?? true }

  /// `NSApp` is nil until an application object exists, which it never does
  /// under `swift test`; no app means no other window can be key.
  var workspaceWindowIsKey: Bool {
    guard let key = NSApp?.keyWindow else { return true }
    return key === mainWindow
  }

  func closeKeyWindow() {
    NSApp.keyWindow?.performClose(nil)
  }

  func chooseDirectory(prompt: String) async -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = prompt
    guard panel.runModal() == .OK else { return nil }
    return panel.url
  }

  func revealInFileBrowser(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  func moveToTrash(_ url: URL) throws {
    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
  }

  func applicationURL(forIdentifier identifier: String) -> URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
  }

  func open(_ directory: URL, withApplication application: URL) async throws {
    _ = try await NSWorkspace.shared.open(
      [directory], withApplicationAt: application, configuration: .init())
  }

  /// `Contents/Helpers/multishell`, or nil outside an app bundle.
  var bundledHelper: URL? {
    let helper = Bundle.main.bundleURL
      .appendingPathComponent("Contents/Helpers/multishell", isDirectory: false)
    return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
  }

  /// Links `/usr/local/bin/multishell` to the stable link, through an
  /// administrator prompt. To the link rather than the bundle, so the tool
  /// survives the app moving.
  func installCommandLineTool() throws {
    let target = ShellQuoting.quote(Paths.helperLink.path)
    let link = ShellQuoting.quote(HelperLink.commandLineToolLink.path)
    let script =
      "do shell script \"mkdir -p /usr/local/bin && ln -sf \(target) \(link)\" with administrator privileges"
    var error: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&error)
    if let error {
      throw CommandLineToolInstallFailed(
        message: error[NSAppleScript.errorMessage] as? String ?? "\(error)")
    }
  }

  /// The Dock tile's badge. An empty label is not the same as none, so a
  /// count of nothing clears it rather than drawing an empty red circle.
  func setBadgeCount(_ count: Int?) {
    NSApp.dockTile.badgeLabel = count.map(String.init)
  }

  func log(_ message: String) {
    logger.notice("\(message, privacy: .public)")
  }
}

struct CommandLineToolInstallFailed: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
