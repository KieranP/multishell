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
    // Placing but not resetting the page, a write to the view's state here
    // being a write during a SwiftUI update. The key pass does the page.
    centre(window)
    let changes: [(NSNotification.Name, @MainActor @Sendable (SettingsWindowResetView) -> Void)] = [
      (NSWindow.didBecomeKeyNotification, { $0.windowDidBecomeKey() }),
      (NSWindow.willCloseNotification, { $0.windowWillClose() }),
      (NSWindow.didResizeNotification, { $0.windowDidResize() }),
    ]
    observers = NotificationCenter.default.observe(changes, from: window, for: self)
  }

  private func windowDidBecomeKey() {
    guard let window, !hasBeenShown else { return }
    hasBeenShown = true
    reset(window)
  }

  private func windowWillClose() {
    guard let window else { return }
    hasBeenShown = false
    reset(window)
  }

  /// The user cannot resize a settings window, so every resize is AppKit
  /// settling: the page toolbar lands late and grows the frame.
  private func windowDidResize() {
    guard let window else { return }
    centre(window)
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

  /// A block observer holds its window, which holds this view, so leaving
  /// one registered past the window would keep both alive.
  private func stopObserving() {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers = []
  }
}
