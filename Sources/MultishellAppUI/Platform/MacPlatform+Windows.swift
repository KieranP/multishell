import AppKit
import MultishellAppCore

extension MacPlatform {
  /// What SwiftUI names the `Settings` scene's window; it offers no way to ask.
  private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"

  var windows: [PlatformWindow] {
    // A sheet is named on the window it covers.
    NSApp.windows.filter { $0.isVisible && !$0.isSheet }.map { window in
      PlatformWindow(
        identifier: window.identifier?.rawValue ?? "",
        title: window.title,
        isKey: window.isKeyWindow,
        width: window.frame.width,
        height: window.frame.height,
        isFullScreen: window.styleMask.contains(.fullScreen),
        sheet: window.attachedSheet?.title,
      )
    }
  }

  var isWorkspaceWindowFullScreen: Bool {
    workspaceWindow?.styleMask.contains(.fullScreen) ?? false
  }

  /// Through the scene's own opener, which `WindowOpenerRegistration` hands over.
  func show(_ window: AuxiliaryWindow) {
    openAuxiliaryWindow?(window)
    NSApp.activate()
  }

  func close(_ window: AuxiliaryWindow) {
    NSApp.windows.first { matches($0, window) }?.close()
  }

  func resizeWorkspaceWindow(width: Double, height: Double) -> Bool {
    guard let window = workspaceWindow, window.isVisible else { return false }
    let frame = WindowResize.frame(
      resizing: window.frame,
      to: NSSize(width: width, height: height),
      minimum: window.minSize,
      within: window.screen?.visibleFrame,
    )
    window.setFrame(frame, display: true)
    return true
  }

  /// The window's own Enter Full Screen, which AppKit adds to View only once
  /// the menu is opened, so the command line cannot find it there.
  func setWorkspaceWindowFullScreen(_ isOn: Bool) -> Bool {
    guard let window = workspaceWindow, window.isVisible else { return false }
    if window.styleMask.contains(.fullScreen) != isOn { window.toggleFullScreen(nil) }
    return true
  }

  func screenshotWorkspaceWindow() -> Data? {
    guard let window = workspaceWindow, window.isVisible, let view = window.contentView else {
      return nil
    }
    return ViewScreenshot.png(of: view)
  }

  private func matches(_ window: NSWindow, _ auxiliary: AuxiliaryWindow) -> Bool {
    let identifier = window.identifier?.rawValue ?? ""
    return switch auxiliary {
    case .settings: identifier == Self.settingsWindowIdentifier
    case .projectSettings: identifier.hasPrefix(ProjectSettingsWindow.windowID)
    }
  }
}
