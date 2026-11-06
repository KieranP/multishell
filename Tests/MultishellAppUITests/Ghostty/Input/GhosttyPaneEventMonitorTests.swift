import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI

@MainActor
@Suite
struct GhosttyPaneEventMonitorTests {
  /// A window never ordered in cannot become key, which a pane needs to have the keyboard.
  private final class KeyWindow: NSWindow {
    override var isKeyWindow: Bool { true }
  }

  @Test func aClickOnTheTopPaneOfAStackedSplitFindsTheTopPane() {
    let content = NSHostingView(rootView: Color.clear)
    content.frame = NSRect(x: 0, y: 0, width: 400, height: 400)
    let window = OffscreenWindow.holding(content)
    let top = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
    let bottom = NSView(frame: NSRect(x: 0, y: 200, width: 400, height: 200))
    content.addSubview(top)
    content.addSubview(bottom)
    let nearTheTop = content.convert(NSPoint(x: 200, y: 20), to: nil)

    withExtendedLifetime(window) {
      #expect(GhosttyPaneEventMonitor.view(at: nearTheTop, in: window) === top)
    }
  }

  @Test func aClickThatOnlyBringsTheWindowForwardStillGivesThePaneTheKeyboard() throws {
    let pane = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    defer { pane.freeSurface() }
    pane.frame = NSRect(x: 0, y: 0, width: 400, height: 400)
    let window = OffscreenWindow.holding(pane, deferred: false)
    let click = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: NSPoint(x: 200, y: 200),
        modifierFlags: [],
        timestamp: 1,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1,
      )
    )

    let isTaken = withExtendedLifetime(window) { GhosttyPaneEventMonitor.deliver(click) }

    // Not `pane.isFirstResponder` inline: a failure describes `pane`, and
    // AppKit's cursors are null pointers in a test process.
    let hasKeyboardFocus = pane.isFirstResponder
    #expect(!isTaken, "the click carries on to the pane")
    #expect(hasKeyboardFocus)
  }

  @Test func aCommandKeyReleaseGoesToThePaneWithTheKeyboard() throws {
    let (pane, window) = paneWithTheKeyboard()
    defer { pane.freeSurface() }

    let isTaken = try withExtendedLifetime(window) {
      GhosttyPaneEventMonitor.deliver(try keyUp(flags: .command, in: window))
    }

    #expect(isTaken)
  }

  @Test func aReleaseWithoutCommandIsLeftToAppKit() throws {
    let (pane, window) = paneWithTheKeyboard()
    defer { pane.freeSurface() }

    let isTaken = try withExtendedLifetime(window) {
      GhosttyPaneEventMonitor.deliver(try keyUp(flags: [], in: window))
    }

    #expect(!isTaken)
  }

  @Test func aModifierChangeOverAPaneWithoutTheKeyboardGoesToThatPane() {
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
    let window = OffscreenWindow.holding(content)
    let focused = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    let hovered = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    defer {
      focused.freeSurface()
      hovered.freeSurface()
    }
    focused.frame = NSRect(x: 0, y: 0, width: 200, height: 400)
    hovered.frame = NSRect(x: 200, y: 0, width: 200, height: 400)
    content.addSubview(focused)
    content.addSubview(hovered)
    window.makeFirstResponder(focused)
    let overHovered = content.convert(NSPoint(x: 300, y: 200), to: nil)
    let overFocused = content.convert(NSPoint(x: 100, y: 200), to: nil)

    withExtendedLifetime(window) {
      let toHovered = GhosttyPaneEventMonitor.paneMissingModifierChanges(
        at: overHovered,
        in: window,
      )
      let toFocused = GhosttyPaneEventMonitor.paneMissingModifierChanges(
        at: overFocused,
        in: window,
      )
      #expect(toHovered === hovered)
      #expect(toFocused == nil, "the pane with the keyboard has its own flagsChanged")
    }
  }

  private func paneWithTheKeyboard() -> (GhosttySurfaceView, NSWindow) {
    let pane = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    let window = KeyWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
      styleMask: [.titled],
      backing: .buffered,
      defer: false,
    )
    window.contentView = pane
    window.makeFirstResponder(pane)
    return (pane, window)
  }

  private func keyUp(flags: NSEvent.ModifierFlags, in window: NSWindow) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: .keyUp,
        location: .zero,
        modifierFlags: flags,
        timestamp: 1,
        windowNumber: window.windowNumber,
        context: nil,
        characters: "c",
        charactersIgnoringModifiers: "c",
        isARepeat: false,
        keyCode: 0x08,
      )
    )
  }
}
