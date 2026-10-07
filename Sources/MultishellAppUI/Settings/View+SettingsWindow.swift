import SwiftUI

extension View {
  /// Sizes a settings window and puts it back on the workspace's screen, first page,
  /// scrolled to the top, each time it opens. Four occasions do that, none enough alone.
  func settingsWindow(platform: MacPlatform, showFirstPage: @escaping () -> Void) -> some View {
    frame(width: UIMetrics.settingsWindowSize.width, height: UIMetrics.settingsWindowSize.height)
      .background(
        SettingsWindowReset(
          workspaceScreen: { platform.workspaceWindow?.screen }, showFirstPage: showFirstPage))
  }
}
