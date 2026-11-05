import MultishellAppCore
import SwiftUI

/// Multishell > Settings: what every project follows and each project's own, one
/// window with its pages in a sidebar. Changes apply as they are made.
struct SettingsWindow: View {
  let model: AppModel
  let platform: MacPlatform

  var body: some View {
    let location = model.settingsLocation
    // A plain row, not a navigation split: the split's toolbar added a sidebar
    // button and an empty band the Settings scene would not take away.
    HStack(spacing: 0) {
      SettingsSidebar(model: model, location: location)
        .frame(width: UIMetrics.settingsSidebarWidth)
      Divider()
      SettingsDetail(model: model, location: location)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // The sidebar runs up under the traffic lights and the page draws its own
    // header in the band, as the workspace window does.
    .ignoresSafeArea(.container, edges: .top)
    .toolbar(removing: .title)
    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    .background(WindowAccessor { $0?.hideTitleBar() })
    .settingsWindow(platform: platform, onClose: { model.returnSettingsToAllProjects() })
    // This window is its own scene, so a removal asked for here has to be
    // confirmed here; the workspace window's dialog would be behind it.
    .projectRemovalAlert(model: model, source: .settings)
  }
}
