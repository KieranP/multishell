import MultishellCore
import SwiftUI

@main
struct MultishellApp: App {
  @State private var model = AppModel()
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    // One window, not a group: every surface is one NSView, and a second
    // window adopting the same views would steal them from the first.
    Window("Multishell", id: "main") {
      RootView(model: model)
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
      SettingsView(model: model)
    }

    // One settings window, retargeted from the sidebar. A `Window`, not a
    // `WindowGroup`: a group makes SwiftUI add its own Close (Cmd+W) to the
    // File menu, which then wins the key equivalent over Close Pane and
    // closes the whole app instead.
    Window("Project Settings", id: ProjectSettingsWindow.windowID) {
      // Reachable from the Window menu too, with no project chosen yet: fall
      // back to the current project rather than showing an empty window.
      if let projectID = model.settingsProjectID ?? model.activeProject?.id {
        ProjectSettingsWindow(model: model, projectID: projectID)
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

struct RootView: View {
  let model: AppModel

  /// Remembered per machine, not in the workspace: it is about this screen.
  @AppStorage("sidebarWidth") private var sidebarWidth = 248.0
  @State private var dragStartWidth: Double?

  private static let sidebarRange = 180.0...440.0

  var body: some View {
    let theme = model.currentTheme
    HStack(spacing: 0) {
      SidebarView(model: model)
        .frame(width: sidebarWidth)
      resizeHandle(theme)
      DetailView(model: model)
    }
    .background(WindowAccessor { model.mainWindow = $0 })
    .ignoresSafeArea()
    .preferredColorScheme(theme.colorScheme)
    .confirmationDialog(
      "Remove worktree \(model.pendingRemoval?.name ?? "")?",
      isPresented: Binding(
        get: { model.pendingRemoval != nil }, set: { if !$0 { model.pendingRemoval = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingRemoval
    ) { worktree in
      Button("Remove Worktree", role: .destructive) {
        model.pendingRemoval = nil
        Task { await model.removeWorktree(worktree) }
      }
      Button("Cancel", role: .cancel) { model.pendingRemoval = nil }
    } message: { worktree in
      Text(
        [
          "Runs git worktree remove on \(worktree.path.path). The branch is kept.",
          model.removalWarning(for: worktree),
        ].compactMap { $0 }.joined(separator: "\n\n"))
    }
    .confirmationDialog(
      model.pendingClose?.title ?? "",
      isPresented: Binding(
        get: { model.pendingClose != nil }, set: { if !$0 { model.pendingClose = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingClose
    ) { pending in
      Button(pending.buttonLabel, role: .destructive) { model.confirmPendingClose() }
      Button("Cancel", role: .cancel) { model.pendingClose = nil }
    } message: { _ in
      Text("An agent here reported that it is still working. Closing ends it.")
    }
    .sheet(item: Bindable(model).newWorktreeRequest) {
      NewWorktreeSheet(model: model, initialProjectID: $0.projectID)
    }
    .alert(item: Bindable(model).presentedError) { error in
      if let label = error.retryLabel, let retry = error.retry {
        Alert(
          title: Text(error.title),
          message: Text(error.message),
          primaryButton: .destructive(Text(label)) { Task { await retry() } },
          secondaryButton: .cancel()
        )
      } else {
        Alert(title: Text(error.title), message: Text(error.message))
      }
    }
  }

  /// The hairline between sidebar and detail, with an 8 pt grab area over it.
  private func resizeHandle(_ theme: Theme) -> some View {
    theme.hairline
      .frame(width: 0.5)
      .overlay {
        Color.clear
          .frame(width: 8)
          .contentShape(.rect)
          .onHover { inside in
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
          }
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
              .onChanged { value in
                let start = dragStartWidth ?? sidebarWidth
                dragStartWidth = start
                sidebarWidth = (start + value.translation.width)
                  .clamped(to: Self.sidebarRange)
              }
              .onEnded { _ in dragStartWidth = nil }
          )
      }
  }
}

extension Double {
  fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
