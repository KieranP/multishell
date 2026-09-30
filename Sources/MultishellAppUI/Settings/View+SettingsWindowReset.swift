import SwiftUI

extension View {
  /// Opens a settings window centred on the workspace's screen, first tab, top
  /// of the page. Placed on four occasions because none alone is enough.
  func settingsWindowReset(
    on workspaceScreen: @escaping () -> NSScreen?, showFirstPage: @escaping () -> Void
  ) -> some View {
    background(SettingsWindowReset(workspaceScreen: workspaceScreen, showFirstPage: showFirstPage))
  }
}
