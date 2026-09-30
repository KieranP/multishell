import SwiftUI

struct SettingsWindowReset: NSViewRepresentable {
  let workspaceScreen: () -> NSScreen?
  let showFirstPage: () -> Void

  func makeNSView(context: Context) -> SettingsWindowResetView {
    let view = SettingsWindowResetView()
    view.workspaceScreen = workspaceScreen
    view.showFirstPage = showFirstPage
    return view
  }

  /// Refreshed rather than captured at make time: these reach into the view's
  /// own state, and a captured copy may not be the live one.
  func updateNSView(_ view: SettingsWindowResetView, context: Context) {
    view.workspaceScreen = workspaceScreen
    view.showFirstPage = showFirstPage
  }
}
