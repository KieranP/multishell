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

  private static let minimumSidebarWidth = 180.0
  /// What the sidebar leaves of the window, so the divider stays in reach.
  static let minimumDetailWidth = 50.0

  var body: some View {
    let theme = model.currentTheme
    GeometryReader { window in
      let range = Self.sidebarRange(inWindowOfWidth: window.size.width)
      HStack(spacing: 0) {
        SidebarView(model: model)
          .frame(width: sidebarWidth.clamped(to: range))
        resizeHandle(theme, range: range)
        DetailView(model: model)
      }
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

  private static func sidebarRange(inWindowOfWidth width: Double) -> ClosedRange<Double> {
    minimumSidebarWidth...max(minimumSidebarWidth, width - minimumDetailWidth)
  }

  /// The hairline between sidebar and detail, with an 8 pt grab area over it.
  private func resizeHandle(_ theme: Theme, range: ClosedRange<Double>) -> some View {
    theme.hairline
      .frame(width: 0.5)
      .overlay {
        Color.clear
          .frame(width: 8)
          .contentShape(.rect)
          .pointerStyle(.columnResize(directions: .all))
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
              .updating($dragStartWidth) { _, start, _ in
                if start == nil { start = sidebarWidth.clamped(to: range) }
              }
              .onChanged { value in
                let start = (dragStartWidth ?? sidebarWidth).clamped(to: range)
                sidebarWidth = (start + value.translation.width).clamped(to: range)
              }
          )
      }
  }
}
