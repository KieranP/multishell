import MultishellAppCore
import MultishellCore
import SwiftUI

/// The workspace window: sidebar, draggable divider, detail. Every dialog it
/// can raise is attached here, each as its own modifier.
struct RootView: View {
  let model: AppModel
  let platform: MacPlatform

  /// Remembered per machine, not in the workspace: they are about this screen.
  @AppStorage(PanelWidthStorage.sidebarKey, store: PanelWidthStorage.defaults)
  private var sidebarWidth = SidebarWidth.initial
  @AppStorage(PanelWidthStorage.filesPanelKey, store: PanelWidthStorage.defaults)
  private var filesPanelWidth = FilesPanelWidth.initial

  var body: some View {
    let theme = model.currentTheme
    GeometryReader { window in
      let widths = SideColumnWidths(
        windowWidth: window.size.width,
        storedSidebar: sidebarWidth,
        storedFilesPanel: model.isFilesPanelOnScreen ? filesPanelWidth : nil,
      )
      let range = SidebarWidth.range(
        inWindowOfWidth: window.size.width,
        besidePanelOf: widths.filesPanel,
      )
      HStack(spacing: 0) {
        SidebarView(model: model)
          .frame(width: sidebarWidth.clamped(to: range))
        ResizeHandle(
          width: $sidebarWidth,
          range: range,
          idealWidth: { SidebarRows.idealWidth(of: model) },
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
    .projectRemovalAlert(model: model, window: .workspace)
    .sharedSettingsTrustDialog(model: model)
    .branchPublishDialog(model: model)
    .pendingCloseAlert(model: model)
    .newWorktreeSheet(model: model)
    .presentedErrorAlert(model: model, window: .workspace)
  }
}
