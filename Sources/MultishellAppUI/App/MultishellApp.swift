import MultishellAppCore
import MultishellCore
import SwiftUI

@main
struct MultishellApp: App {
  @State private var platform: MacPlatform
  @State private var model: AppModel
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  init() {
    let platform = MacPlatform()
    _platform = State(initialValue: platform)
    _model = State(initialValue: AppModel(platform: platform))
  }

  var body: some Scene {
    // One window, not a group: every surface is one NSView, and a second
    // window adopting the same views would steal them from the first.
    Window("Multishell", id: "main") {
      RootView(model: model, platform: platform)
        .frame(minWidth: 720, minHeight: 420)
        .task {
          appDelegate.liveTerminalCount = { model.liveTerminalCount }
          appDelegate.workingAgentCount = { model.workingAgentCount }
          appDelegate.onWillTerminate = {
            model.shutDown()
          }
          await model.start()
        }
    }
    // The chrome is drawn by the views; the system title bar would add a
    // second one and macOS 26 would float the sidebar in glass.
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    .commands { MultishellCommands(model: model) }

    Settings {
      AppSettingsWindow(model: model, platform: platform)
    }

    // One settings window, retargeted from the sidebar. A `Window`, not a
    // `WindowGroup`, whose own Cmd+W would win over Close Pane.
    Window(t("window.project-settings"), id: ProjectSettingsWindow.windowID) {
      if let projectID = model.settingsWindowProjectID {
        ProjectSettingsWindow(model: model, platform: platform, projectID: projectID)
      } else {
        Text(t("window.project-settings-empty"))
          .foregroundStyle(.secondary)
          .frame(width: 400, height: 120)
      }
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}
