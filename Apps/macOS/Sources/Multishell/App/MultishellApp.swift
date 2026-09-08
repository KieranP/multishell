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
          appDelegate.openTerminalCount = { model.liveTerminalCount }
          appDelegate.workingAgentCount = { model.workingAgentCount }
          appDelegate.willTerminate = { model.shutDown() }
          await model.start()
        }
    }
    // The chrome is drawn by the views; the system title bar would add a
    // second one and macOS 26 would float the sidebar in glass.
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    .commands { MultishellCommands(model: model) }

    Settings {
      SettingsView(model: model, platform: platform)
    }

    // One settings window, retargeted from the sidebar. A `Window`, not a
    // `WindowGroup`: a group makes SwiftUI add its own Close (Cmd+W) to the
    // File menu, which then wins the key equivalent over Close Pane and
    // closes the whole app instead.
    Window("Project Settings", id: ProjectSettingsWindow.windowID) {
      // Reachable from the Window menu too, with no project chosen yet: fall
      // back to the current project rather than showing an empty window.
      if let projectID = model.settingsProjectID ?? model.activeProject?.id {
        ProjectSettingsWindow(model: model, platform: platform, projectID: projectID)
      } else {
        Text("Right-click a project in the sidebar and choose Project Settings.")
          .foregroundStyle(.secondary)
          .frame(width: 400, height: 120)
      }
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}
