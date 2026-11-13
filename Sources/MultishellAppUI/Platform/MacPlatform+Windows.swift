import AppKit
import MultishellAppCore
import MultishellCore

extension MacPlatform {
  /// What SwiftUI names the `Settings` scene's window; it offers no way to ask.
  private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"

  var windows: [PlatformWindow] {
    // A sheet is named on the window it covers; a minimized window is open too.
    NSApp.windows.filter { ($0.isVisible || $0.isMiniaturized) && !$0.isSheet }.map { window in
      PlatformWindow(
        identifier: window.identifier?.rawValue ?? "",
        title: window.title,
        isKey: window.isKeyWindow,
        width: window.frame.width,
        height: window.frame.height,
        isFullScreen: window.styleMask.contains(.fullScreen),
        isMinimized: window.isMiniaturized,
        sheet: window.attachedSheet?.title,
      )
    }
  }

  var isWorkspaceWindowFullScreen: Bool {
    workspaceWindow?.styleMask.contains(.fullScreen) ?? false
  }

  /// Shown or minimized: AppKit counts a minimized window as not visible.
  private var openWorkspaceWindow: NSWindow? {
    workspaceWindow.flatMap { $0.isVisible || $0.isMiniaturized ? $0 : nil }
  }

  /// On a screen, as sizing, full screen and a screenshot need.
  private var shownWorkspaceWindow: NSWindow? {
    workspaceWindow.flatMap { $0.isVisible ? $0 : nil }
  }

  var isWorkspaceWindowMinimized: Bool { workspaceWindow?.isMiniaturized ?? false }

  var isSettingsWindowKey: Bool {
    guard let key = NSApp?.keyWindow else { return false }
    return matches(key.sheetParent ?? key, .settings)
  }

  var workspaceWindowWidth: Double? { openWorkspaceWindow.map { Double($0.frame.width) } }

  /// Through the scene's own opener, which `registeringWindowOpeners` hands over.
  func show(_ window: AuxiliaryWindow) {
    openAuxiliaryWindow?(window)
    NSApp.activate()
  }

  func close(_ window: AuxiliaryWindow) {
    NSApp.windows.first { matches($0, window) }?.close()
  }

  func resizeWorkspaceWindow(width: Double, height: Double) -> Bool {
    guard let window = shownWorkspaceWindow else { return false }
    let frame = WindowResize.frame(
      resizing: window.frame,
      to: NSSize(width: width, height: height),
      minimum: window.minSize,
      within: window.screen?.visibleFrame,
    )
    window.setFrame(frame, display: true)
    return true
  }

  func width(of panel: ResizablePanel) -> Double {
    PanelWidthStorage.defaults.object(forKey: PanelWidthStorage.key(of: panel)) as? Double
      ?? panel.initialWidth
  }

  /// Written where the views' `@AppStorage` reads, which redraws them.
  func setWidth(of panel: ResizablePanel, to width: Double) -> Bool {
    guard openWorkspaceWindow != nil else { return false }
    PanelWidthStorage.defaults.set(width, forKey: PanelWidthStorage.key(of: panel))
    return true
  }

  /// The window's own Enter Full Screen, which AppKit adds to View only once
  /// the menu is opened, so the command line cannot find it there.
  func setWorkspaceWindowFullScreen(_ isOn: Bool) -> Bool {
    guard let window = shownWorkspaceWindow else { return false }
    if window.styleMask.contains(.fullScreen) != isOn { window.toggleFullScreen(nil) }
    return true
  }

  func screenshotWorkspaceWindow() -> Data? {
    guard let view = shownWorkspaceWindow?.contentView else { return nil }
    return ViewScreenshot.png(of: view)
  }

  /// The frame view holding the content, so the title bar and toolbar draw too.
  func screenshotSettingsWindow() -> Data? {
    guard let window = NSApp.windows.first(where: { matches($0, .settings) }), window.isVisible,
      let frame = window.contentView?.superview
    else { return nil }
    return ViewScreenshot.png(of: frame)
  }

  private func matches(_ window: NSWindow, _ auxiliary: AuxiliaryWindow) -> Bool {
    let identifier = window.identifier?.rawValue ?? ""
    return switch auxiliary {
    case .settings: identifier == Self.settingsWindowIdentifier
    }
  }
}
