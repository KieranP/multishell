import MultishellAppCore
import MultishellCore
import SwiftUI

/// The workspace window: sidebar, draggable divider, detail. Every dialog it
/// can raise is attached here, each as its own modifier.
struct RootView: View {
  let model: AppModel
  let platform: MacPlatform

  /// Remembered per machine, not in the workspace: it is about this screen.
  @AppStorage("sidebarWidth") private var sidebarWidth = 248.0
  /// Gesture state, not `@State`: a drag the system cancels never reaches
  /// `onEnded`, and this resets either way; see `SplitHandle`.
  @GestureState private var dragStartWidth: Double?

  private static let sidebarRange = 180.0...440.0

  var body: some View {
    let theme = model.currentTheme
    HStack(spacing: 0) {
      SidebarView(model: model)
        .frame(width: sidebarWidth)
      resizeHandle(theme)
      DetailView(model: model)
    }
    .background(WindowAccessor { platform.mainWindow = $0 })
    .ignoresSafeArea()
    .preferredColorScheme(theme.colorScheme)
    .worktreeRemovalDialog(model: model)
    .projectRemovalDialog(model: model, source: .workspace)
    .sharedSettingsTrustDialog(model: model)
    .pendingCloseDialog(model: model)
    .newWorktreeSheet(model: model)
    .presentedErrorAlert(model: model)
  }

  /// The hairline between sidebar and detail, with an 8 pt grab area over it.
  private func resizeHandle(_ theme: Theme) -> some View {
    theme.hairline
      .frame(width: 0.5)
      .overlay {
        Color.clear
          .frame(width: 8)
          .contentShape(.rect)
          .cursorPush(.resizeLeftRight)
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
              .updating($dragStartWidth) { _, start, _ in
                if start == nil { start = sidebarWidth }
              }
              .onChanged { value in
                let start = dragStartWidth ?? sidebarWidth
                sidebarWidth = (start + value.translation.width)
                  .clamped(to: Self.sidebarRange)
              }
          )
      }
  }
}
