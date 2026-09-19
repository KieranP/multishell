import AppKit
import SwiftUI

/// Opens a settings window centred on the workspace's screen, first tab, top
/// of the page. Placed on four occasions because none alone is enough.
struct SettingsWindowReset: ViewModifier {
  let workspaceScreen: () -> NSScreen?
  let showFirstTab: () -> Void

  func body(content: Content) -> some View {
    content.background(
      SettingsWindowPlacer(workspaceScreen: workspaceScreen, showFirstTab: showFirstTab))
  }
}

extension View {
  func settingsWindowReset(
    on workspaceScreen: @escaping () -> NSScreen?, showFirstTab: @escaping () -> Void
  ) -> some View {
    modifier(SettingsWindowReset(workspaceScreen: workspaceScreen, showFirstTab: showFirstTab))
  }
}

private struct SettingsWindowPlacer: NSViewRepresentable {
  let workspaceScreen: () -> NSScreen?
  let showFirstTab: () -> Void

  func makeNSView(context: Context) -> Placer {
    let view = Placer()
    view.workspaceScreen = workspaceScreen
    view.showFirstTab = showFirstTab
    return view
  }

  /// Refreshed rather than captured at make time: these reach into the view's
  /// own state, and a captured copy may not be the live one.
  func updateNSView(_ view: Placer, context: Context) {
    view.workspaceScreen = workspaceScreen
    view.showFirstTab = showFirstTab
  }

  final class Placer: NSView {
    var workspaceScreen: (() -> NSScreen?)?
    var showFirstTab: (() -> Void)?

    private var observers: [any NSObjectProtocol] = []
    /// Whether the window this view is in is one the user has already been
    /// shown, so that becoming key can tell a reopen from a raise.
    private var isOpen = false

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      stopObserving()
      isOpen = false
      guard let window else { return }
      // Placing but not resetting the tab, a write to the view's state here
      // being a write during a SwiftUI update. The key pass does the tab.
      centre(window)
      observe(NSWindow.didBecomeKeyNotification, from: window) { [weak self] window in
        guard let self, !isOpen else { return }
        isOpen = true
        reset(window)
      }
      observe(NSWindow.willCloseNotification, from: window) { [weak self] window in
        guard let self else { return }
        isOpen = false
        reset(window)
      }
      // The user cannot resize a settings window, so every resize is AppKit
      // settling: the tab band lands late and grows the frame.
      observe(NSWindow.didResizeNotification, from: window) { [weak self] window in
        self?.centre(window)
      }
    }

    private func reset(_ window: NSWindow) {
      centre(window)
      showFirstTab?()
      window.contentView?.scrollDescendantsToTop()
    }

    /// The workspace's screen, not the window's own, or a settings window on
    /// a second display keeps reopening there. Its own is the fallback.
    private func centre(_ window: NSWindow) {
      guard let screen = workspaceScreen?() ?? window.screen ?? NSScreen.main else { return }
      let area = screen.visibleFrame
      let size = window.frame.size
      let origin = CGPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)
      guard window.frame.origin != origin else { return }
      window.setFrameOrigin(origin)
    }

    private func observe(
      _ name: Notification.Name, from window: NSWindow,
      then act: @escaping @MainActor (NSWindow) -> Void
    ) {
      observers.append(
        NotificationCenter.default.addObserver(
          forName: name, object: window, queue: .main
        ) { [weak window] _ in
          // Registered against the main queue, so this is the main actor.
          MainActor.assumeIsolated {
            guard let window else { return }
            act(window)
          }
        })
    }

    /// A block observer holds its window, which holds this view, so leaving
    /// one registered past the window would keep both alive.
    private func stopObserving() {
      for observer in observers { NotificationCenter.default.removeObserver(observer) }
      observers = []
    }
  }
}
