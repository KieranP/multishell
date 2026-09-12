import AppKit
import Testing

@testable import Multishell

/// A pane's frame is reused: `PaneTreeView` renders split children by index,
/// so closing one leaves the frame that held it showing the next session's
/// surface. What it asks for focus has to move with the surface.
@Suite @MainActor
struct SurfaceFrameTests {
  /// A window never ordered in, focus being refused to a view that is in
  /// none; see docs/develop/build.md.
  private func framed() -> (window: NSWindow, frame: SurfaceFrame) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled],
      backing: .buffered, defer: false)
    let frame = SurfaceFrame()
    window.contentView?.addSubview(frame)
    return (window, frame)
  }

  @Test func aFrameGivenAnotherSessionsSurfaceAsksThatSessionForFocus() {
    let (window, frame) = framed()
    var asked: [String] = []
    frame.show(NSView(), focused: true) { asked.append("first") }
    #expect(asked == ["first"])

    // The pane holding the first session closes and this frame slides on to
    // the next, which is focused as the first was.
    frame.show(NSView(), focused: true) { asked.append("second") }
    #expect(asked == ["first", "second"], "the closed pane was asked for the open one")
    _ = window
  }

  @Test func aPassThatChangesNothingDoesNotTakeTheKeyboardBack() {
    let (window, frame) = framed()
    var asked = 0
    let surface = NSView()
    frame.show(surface, focused: true) { asked += 1 }
    frame.show(surface, focused: true) { asked += 1 }
    #expect(asked == 1, "typing in a field elsewhere is not interrupted")
    _ = window
  }

  @Test func aFrameHandedAnUnfocusedSessionDoesNotKeepTheLastOnesClaim() {
    let (window, frame) = framed()
    var asked = 0
    frame.show(NSView(), focused: true) { asked += 1 }
    frame.show(NSView(), focused: false) { asked += 1 }
    #expect(asked == 1, "the new session is not the focused one")
    _ = window
  }
}
