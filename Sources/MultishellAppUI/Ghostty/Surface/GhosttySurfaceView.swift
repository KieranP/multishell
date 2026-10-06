import AppKit
import GhosttyKit

/// One terminal: a libghostty surface drawing into this view, after Ghostty's
/// own `SurfaceView_AppKit`. Its shell starts as the view is made.
@MainActor
final class GhosttySurfaceView: NSView {
  /// `nil` once freed, or where libghostty refused to make it.
  private(set) var surface: ghostty_surface_t?
  var onRetitle: ((String) -> Void)?
  var onBell: (() -> Void)?
  var onCommandFinish: ((Int?) -> Void)?
  /// The shell's process ended and libghostty closed the pane.
  var onExit: (() -> Void)?
  /// libghostty was asked to close the pane while its process runs, as by a keybind.
  var onCloseRequest: (() -> Void)?
  /// The keyboard reached this pane; whether it stays is the caller's question.
  var onFocus: (() -> Void)?

  /// The input method's uncommitted text, empty when nothing is composing.
  var markedText = ""
  /// Text the input method commits during one `keyDown`, sent after it.
  var textCommittedInKeyDown: [String]?
  var keyEquivalent = GhosttyKeyEquivalent()
  var surrogatePairing = GhosttySurrogatePairing()
  private var windowObservers: [any NSObjectProtocol] = []
  /// An unsafe paste waiting on the user, and the sheet asking about it.
  var pendingPaste: (paste: GhosttyPasteConfirmation, alert: NSAlert)?
  /// What a program or libghostty last asked the pointer to be over the pane.
  private var pointer = NSCursor.iBeam
  /// Held so libghostty's app outlives every surface made in it.
  let runtime: GhosttyRuntime
  /// libghostty saw this pane's program turn echo off, as at a password
  /// prompt, or the `toggle_secure_input` keybind asked for it.
  private var wantsSecureInput = false

  init(runtime: GhosttyRuntime, launch: GhosttySurfaceLaunch) {
    self.runtime = runtime
    super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    surface = launch.withCConfig(view: self, scale: scale) { ghostty_surface_new(runtime.app, &$0) }
    // libghostty starts a surface focused and drawing; a pane opened out of
    // sight is neither until it is shown.
    updateFocus()
    updateVisibility()
    updateTrackingAreas()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// libghostty holds this view unretained as the surface's userdata, so a
  /// view let go unfreed would leave it a dangling pointer and the shell running.
  isolated deinit {
    freeSurface()
  }

  /// Ends the shell. Not from the surface's own close callback, which runs
  /// inside libghostty and would free the surface mid-call.
  func freeSurface() {
    answerPendingPaste(approved: false)
    runtime.secureInput.remove(ObjectIdentifier(self))
    guard let surface else { return }
    ghostty_surface_free(surface)
    self.surface = nil
  }

  override var acceptsFirstResponder: Bool { true }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    resizeSurface()
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    if let window {
      // libghostty scales the drawing itself, so the layer must not again.
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      layer?.contentsScale = window.backingScaleFactor
      CATransaction.commit()
    }
    resizeSurface()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    observeWindow()
    updateFocus()
    updateColorScheme()
    updateVisibility()
    updateDisplay()
    viewDidChangeBackingProperties()
  }

  override func updateTrackingAreas() {
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(
      NSTrackingArea(
        rect: bounds,
        options: [.mouseEnteredAndExited, .mouseMoved, .inVisibleRect, .activeAlways],
        owner: self))
    super.updateTrackingAreas()
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: pointer)
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColorScheme()
  }

  /// Dropped once freed: a report queued from another thread can land after.
  /// The pointer and secure input are the view's own to answer; the rest go to the host.
  func receive(_ event: GhosttySurfaceEvent) {
    guard surface != nil else { return }
    switch event {
    case .retitled(let title):
      onRetitle?(title)
    case .bell:
      onBell?()
    case .commandFinished(let exitCode):
      onCommandFinish?(exitCode)
    case .pointerShape(let shape):
      guard let cursor = GhosttyPointerShape.cursor(for: shape) else { return }
      pointer = cursor
      window?.invalidateCursorRects(for: self)
    case .pointerVisible(let visible):
      NSCursor.setHiddenUntilMouseMoves(!visible)
    case .secureInput(let mode):
      wantsSecureInput = GhosttySecureInput.wantsSecureInput(after: mode, was: wantsSecureInput)
      syncSecureInput(hasKeyboard: hasKeyboard)
    }
  }

  /// Asked of libghostty, not read off the callback's flag, which says whether
  /// Ghostty would confirm the close rather than whether the process is there.
  func surfaceDidClose() {
    guard let surface else { return }
    if ghostty_surface_process_exited(surface) { onExit?() } else { onCloseRequest?() }
  }

  /// Not out of a window, where the backing scale is the main screen's rather
  /// than the one the pane was on, so a tab switch rebuilt its font grid twice.
  private func resizeSurface() {
    guard let surface, window != nil, bounds.width > 0, bounds.height > 0 else { return }
    let backing = convertToBacking(bounds)
    ghostty_surface_set_content_scale(
      surface, backing.width / bounds.width, backing.height / bounds.height)
    ghostty_surface_set_size(surface, UInt32(backing.width), UInt32(backing.height))
  }

  /// Drawing stops while no one can see it, off screen or behind a window.
  private func updateVisibility() {
    guard let surface else { return }
    ghostty_surface_set_occlusion(surface, window?.occlusionState.contains(.visible) ?? false)
  }

  /// libghostty paces drawing to the display the window is on.
  private func updateDisplay() {
    guard let surface, let number = window?.screen?.deviceDescription[.init("NSScreenNumber")]
    else { return }
    ghostty_surface_set_display_id(surface, (number as? NSNumber)?.uint32Value ?? 0)
  }

  /// The scale is read again a turn later, once the window has settled on the
  /// new screen, as Ghostty's app does for a missed backing change (ghostty#2731).
  private func windowDidChangeScreen() {
    updateDisplay()
    DispatchQueue.main.async { [weak self] in self?.viewDidChangeBackingProperties() }
  }

  /// Secure input follows the keyboard: on only while this prompt has it.
  /// `hasKeyboard` is passed in, AppKit naming a new responder only afterwards.
  func syncSecureInput(hasKeyboard: Bool) {
    runtime.secureInput.update(
      ObjectIdentifier(self), wantsSecureInput: wantsSecureInput, hasKeyboard: hasKeyboard)
  }

  /// A program asking whether the terminal is light or dark is told the
  /// app's theme, which the view's appearance follows.
  private func updateColorScheme() {
    guard let surface else { return }
    ghostty_surface_set_color_scheme(surface, GhosttyColorScheme.scheme(for: effectiveAppearance))
  }

  private func observeWindow() {
    windowObservers.forEach(NotificationCenter.default.removeObserver)
    guard let window else {
      windowObservers = []
      return
    }
    let changes: [(NSNotification.Name, @MainActor @Sendable (GhosttySurfaceView) -> Void)] = [
      (NSWindow.didChangeOcclusionStateNotification, { $0.updateVisibility() }),
      (NSWindow.didChangeScreenNotification, { $0.windowDidChangeScreen() }),
      (NSWindow.didBecomeKeyNotification, { $0.windowKeyDidChange() }),
      (NSWindow.didResignKeyNotification, { $0.windowKeyDidChange() }),
    ]
    windowObservers = NotificationCenter.default.observe(changes, from: window, for: self)
  }
}
