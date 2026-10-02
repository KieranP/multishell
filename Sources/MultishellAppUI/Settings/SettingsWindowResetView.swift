import AppKit

final class SettingsWindowResetView: AccessibilityHiddenView {
  var workspaceScreen: (() -> NSScreen?)?
  var showFirstPage: (() -> Void)?

  private var observers: [any NSObjectProtocol] = []
  /// Whether the window this view is in is one the user has already been
  /// shown, so that becoming key can tell a reopen from a raise.
  private var hasBeenShown = false

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    stopObserving()
    hasBeenShown = false
    guard let window else { return }
    // Placing but not resetting the tab, a write to the view's state here
    // being a write during a SwiftUI update. The key pass does the tab.
    centre(window)
    observe(NSWindow.didBecomeKeyNotification, from: window) { [weak self] window in
      guard let self, !hasBeenShown else { return }
      hasBeenShown = true
      reset(window)
    }
    observe(NSWindow.willCloseNotification, from: window) { [weak self] window in
      guard let self else { return }
      hasBeenShown = false
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
    showFirstPage?()
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
