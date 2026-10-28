import MultishellAppCore
import MultishellCore
import SwiftUI

/// The workspace window: sidebar, draggable divider, detail. Every dialog it
/// can raise is attached here, each as its own modifier.
struct RootView: View {
  let model: AppModel
  let platform: MacPlatform

  /// Remembered per machine, not in the workspace: they are about this screen.
  @AppStorage("sidebarWidth") private var sidebarWidth = SidebarWidth.initial
  @AppStorage(FilesPanelStorage.widthKey) private var filesPanelWidth = FilesPanelWidth.initial

  var body: some View {
    let theme = model.currentTheme
    GeometryReader { window in
      let range = SidebarWidth.range(
        inWindowOfWidth: window.size.width,
        besidePanelOf: model.isFilesPanelOnScreen ? filesPanelWidth : 0,
      )
      HStack(spacing: 0) {
        SidebarView(model: model)
          .frame(width: sidebarWidth.clamped(to: range))
        ResizeHandle(
          width: $sidebarWidth,
          range: range,
          initial: SidebarWidth.initial,
          dragged: SidebarWidth.dragged,
          palette: theme.projectsPanel,
        )
        DetailView(model: model)
      }
    }
    .overlay { QuickSwitcherLayer(model: model) }
    .background(WindowAccessor { platform.workspaceWindow = $0 })
    .registeringWindowOpeners(with: platform)
    .ignoresSafeArea()
    .preferredColorScheme(theme.colorScheme)
    .worktreeRemovalAlert(model: model)
    .projectRemovalAlert(model: model, source: .workspace)
    .sharedSettingsTrustDialog(model: model)
    .branchPublishDialog(model: model)
    .pendingCloseAlert(model: model)
    .newWorktreeSheet(model: model)
    .presentedErrorAlert(model: model)
  }
}
