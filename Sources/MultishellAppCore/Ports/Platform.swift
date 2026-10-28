import Foundation

/// What the model needs from the desktop and nothing more, so it compiles
/// and is tested without a window, a pasteboard or a workspace API.
@MainActor
public protocol Platform: AnyObject, Sendable {
  /// Whether the app is frontmost. Status polling pauses while it is not,
  /// and a report about the shown tab still earns a banner then.
  var isActive: Bool { get }
  /// Called when the app comes back to the front, so stale badges refresh.
  var onDidBecomeActive: (@MainActor () -> Void)? { get set }
  /// Whether a keyboard command should act on the workspace: in any other
  /// window Cmd+W closes that window, not a pane nobody can see.
  var isWorkspaceWindowKey: Bool { get }
  /// Whether any of the workspace window is on screen, frontmost or not: file
  /// tabs and the Files panel stay current while it is; see files.md.
  var isWorkspaceWindowVisible: Bool { get }
  /// Called when the workspace window comes back on screen, for the reads
  /// held back while it was covered.
  var onWorkspaceWindowDidBecomeVisible: (@MainActor () -> Void)? { get set }

  /// The helper binary shipped with this build, or `nil` outside a bundle.
  /// `HelperLink` points the stable link at it on launch.
  var bundledHelper: URL? { get }

  /// Where the desktop grants notification permission, as the user would find
  /// it. `nil` where there is no such place to name.
  var notificationSettingsLocation: String? { get }

  /// The app's open windows, for `multishell info`.
  var windows: [PlatformWindow] { get }
  /// Every item of the menu bar, for `multishell ui menu`.
  var menuItems: [PlatformMenuItem] { get }
  /// The app's own of those, without what macOS adds, for the quick switcher.
  var commandMenuItems: [PlatformMenuItem] { get }
  var isWorkspaceWindowFullScreen: Bool { get }

  func closeKeyWindow()

  /// A directory picker, or `nil` when the user cancels.
  func chooseDirectory(prompt: String) async -> URL?
  func revealInFileBrowser(_ url: URL)
  /// A web page in the default browser; the model hands it only http and https.
  func openWebPage(_ url: URL)
  func copyToClipboard(_ text: String)
  /// The alert sound, for a click that does nothing, as a refused link's does.
  func beep()

  /// Whether a file opens as text, by a clicked link's rule; blocking, so run
  /// through `runOnDispatch`. See Docs/design/files.md.
  nonisolated func opensAsText(_ file: URL) -> Bool
  /// The same rule for a copy git holds, by its name's type or its first bytes.
  nonisolated func opensAsText(named name: String, startingWith bytes: Data) -> Bool

  /// Moves a removed worktree's directory to the Trash, throwing where it
  /// will not take it. Off the main actor: a large tree is walked here.
  nonisolated func moveToTrash(_ url: URL) throws

  /// Where an installed application lives, by bundle identifier, or `nil`
  /// where the platform has no such lookup.
  func applicationURL(forIdentifier identifier: String) -> URL?
  /// Hands a directory or file to an application found by `applicationURL`.
  func open(_ item: URL, withApplication application: URL) async throws
  /// The app plain text opens in, for a file whose own type's app, a script's,
  /// could run it; `nil` where none takes text.
  func plainTextEditorURL() -> URL?
  /// Links the helper somewhere on the default PATH, behind whatever
  /// privilege prompt the platform needs.
  func installCommandLineTool() throws

  /// The count on the app's icon, `nil` for no badge: the Agents board's
  /// Waiting column. A platform with no such place does nothing.
  func setBadgeCount(_ count: Int?)

  /// A line for the platform's log, for what is worth a note but not an
  /// alert.
  func log(_ message: String)

  /// Calls `onFrame` on the main thread once per display refresh until stopped,
  /// late when the main thread is busy: Debug Info's frame rate.
  func startDisplayFrameCallbacks(_ onFrame: @escaping @MainActor (ContinuousClock.Instant) -> Void)
  func stopDisplayFrameCallbacks()

  /// Another copy of this build holds the socket: bring it forward and quit
  /// this one. A platform with no such notion does nothing and returns.
  func handOverToRunningInstance()

  /// Quits without the confirmation, the command line having asked for it.
  func quit()

  func show(_ window: AuxiliaryWindow)
  func close(_ window: AuxiliaryWindow)
  /// `false` where the main window is closed.
  func resizeWorkspaceWindow(width: Double, height: Double) -> Bool
  /// `false` where the main window is closed; the change animates in after.
  func setWorkspaceWindowFullScreen(_ isOn: Bool) -> Bool
  /// The main window as drawn, its panes included, as a PNG; `nil` where it
  /// is closed or has not drawn.
  func screenshotWorkspaceWindow() -> Data?
  /// A named instant in the platform's trace, where a profiler lines it up.
  func signpost(_ name: String)
  /// The item at `path`, titles from the bar down, chosen as a click would.
  func performMenuItem(_ path: [String]) -> PlatformMenuOutcome
  /// The user's own choice of the item, once the window has redrawn and the
  /// keyboard is back where the item acts; a beep where it cannot be chosen.
  func chooseMenuItem(_ path: [String])
  /// Whether a font family by this name is installed now, as the font picker lists them.
  func hasFontFamily(_ family: String) -> Bool
}
