import MultishellAppCore
import SwiftUI

struct MultishellApp: App {
  @State private var platform: MacPlatform
  @State private var model: AppModel
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    // One window, not a group: every surface is one NSView, and a second
    // window adopting the same views would steal them from the first.
    Window(t("window.main"), id: "main") {
      RootView(model: model, platform: platform)
        .frame(minWidth: 720, minHeight: 420)
        .task {
          appDelegate.asksBeforeQuitting = { model.asksBeforeQuitting }
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

    // Every project's settings and each project's own, Project Settings…
    // opening it on that project.
    Settings {
      SettingsWindow(model: model, platform: platform)
    }
  }

  init() {
    let platform = MacPlatform()
    let model = AppModel(platform: platform)
    platform.isCommandAvailable = { [weak model] title in
      model?.isMenuCommandAvailable(titled: title) ?? true
    }
    _platform = State(initialValue: platform)
    _model = State(initialValue: model)
  }
}
