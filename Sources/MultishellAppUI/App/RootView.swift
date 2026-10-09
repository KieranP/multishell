import MultishellAppCore
import MultishellCore
import SwiftUI

/// The workspace window: sidebar, draggable divider, detail. Every dialog it
/// can raise is attached here, each as its own modifier.
struct RootView: View {
  private static let resizeGrabWidth: Double = 8

  let model: AppModel
  let platform: MacPlatform

  /// Remembered per machine, not in the workspace: it is about this screen.
  @AppStorage("sidebarWidth") private var sidebarWidth = SidebarWidth.initial
  /// Gesture state, not `@State`: a drag the system cancels never reaches
  /// `onEnded`, and this resets either way; see `SplitDivider`.
  @GestureState private var dragStartWidth: Double?

  var body: some View {
    let theme = model.currentTheme
    GeometryReader { window in
      let range = SidebarWidth.range(inWindowOfWidth: window.size.width)
      HStack(spacing: 0) {
        SidebarView(model: model)
          .frame(width: sidebarWidth.clamped(to: range))
        resizeHandle(theme, range: range)
        DetailView(model: model)
      }
    }
    .background(WindowAccessor { platform.workspaceWindow = $0 })
    .ignoresSafeArea()
    .preferredColorScheme(theme.colorScheme)
    .worktreeRemovalAlert(model: model)
    .projectRemovalAlert(model: model, source: .workspace)
    .sharedSettingsTrustDialog(model: model)
    .pendingCloseAlert(model: model)
    .newWorktreeSheet(model: model)
    .presentedErrorAlert(model: model)
  }

  /// The hairline between sidebar and detail, with a wider grab area over it.
  private func resizeHandle(_ theme: Theme, range: ClosedRange<Double>) -> some View {
    theme.hairline
      .frame(width: UIMetrics.hairlineThickness)
      .overlay {
        Color.clear
          .frame(width: Self.resizeGrabWidth)
          .contentShape(.rect)
          .pointerStyle(.columnResize(directions: .all))
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
              .updating($dragStartWidth) { _, start, _ in
                if start == nil { start = sidebarWidth.clamped(to: range) }
              }
              .onChanged { value in
                sidebarWidth = SidebarWidth.dragged(
                  from: dragStartWidth ?? sidebarWidth,
                  by: value.translation.width,
                  in: range,
                )
              }
          )
      }
  }
}
