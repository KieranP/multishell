import AppKit
import SwiftUI

/// Opens a settings window centred on the workspace window's screen, on its
/// first tab and scrolled to the top, however the user left it last time.
///
/// The placing happens on four occasions, because no one of them is enough.
/// SwiftUI may keep a settings scene's window alive across a close and show
/// that same window again, so a close places it while nothing is on screen
/// to jump; the attach pass covers the first open of a launch, whose frame
/// the system restores from disk; becoming key is the first point that knows
/// which screen the workspace is on; and a resize is the window settling to
/// its content after all of those, which moves it off centre again. Each
/// pass after the first normally finds the window already where it wants it
/// and moves nothing.
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

  /// Refreshed rather than left as the pair handed over at make time: these
  /// reach into the view's own state, and a captured copy of it read back
  /// later is not guaranteed to be the live one.
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
      // Placing but not resetting the tab: a write to the view's state in a
      // layout pass is a write during a SwiftUI update. The key pass that
      // follows this one does the tab.
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
      // A settings window is sized by its content and cannot be resized by
      // the user, so every resize is AppKit settling that layout: a toolbar's
      // tab band lands after the first pass and grows the frame, leaving a
      // window placed before it half that growth off centre.
      observe(NSWindow.didResizeNotification, from: window) { [weak self] window in
        self?.centre(window)
      }
    }

    private func reset(_ window: NSWindow) {
      centre(window)
      showFirstTab?()
      window.contentView?.scrollDescendantsToTop()
    }

    /// The workspace's screen, not the window's own: a settings window left
    /// on a second display would otherwise keep reopening there, away from
    /// the app. Its own screen is the fallback for a workspace window that
    /// is on none, such as a minimised one.
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
