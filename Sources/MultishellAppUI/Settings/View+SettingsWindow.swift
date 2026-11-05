import SwiftUI

extension View {
  /// Sizes the settings window and puts it back on the workspace's screen,
  /// scrolled to the top, each time it opens; `onClose` resets where it is.
  func settingsWindow(platform: MacPlatform, onClose: @escaping () -> Void) -> some View {
    frame(width: UIMetrics.settingsWindowSize.width, height: UIMetrics.settingsWindowSize.height)
      .background(
        SettingsWindowReset(
          workspaceScreen: { platform.workspaceWindow?.screen },
          onClose: onClose,
        )
      )
  }
}
