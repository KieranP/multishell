import AppKit
import GhosttyKit

/// libghostty looks for no link while a program holds the mouse, so Cmd's hand
/// and Cmd+click are given here to what reads as one; see terminals/links.md.
extension GhosttySurfaceView {
  /// Over libghostty's arrow only: any other shape is the program's own choice.
  var shownPointer: NSCursor {
    programLinkUnderPointer != nil && pointer === NSCursor.arrow ? .pointingHand : pointer
  }

  /// Backing pixels from the top left, as libghostty counts its rows.
  func pixelFromTopLeft(of point: NSPoint) -> CGPoint {
    convertToBacking(CGPoint(x: point.x, y: bounds.height - point.y))
  }

  /// `point` in the view's own space. The pane is read only when the pointer
  /// reaches another cell, each read taking the renderer's lock.
  func judgeProgramLink(at point: NSPoint, isCommandHeld: Bool) {
    // A drag goes on past the edge, where libghostty reads the edge cell's word.
    guard let surface, isCommandHeld, bounds.contains(point) else {
      forgetProgramLink()
      return
    }
    let size = ghostty_surface_size(surface)
    let cellSize = CGSize(width: Double(size.cell_width_px), height: Double(size.cell_height_px))
    guard let cell = GhosttyPointerCell(pixel: pixelFromTopLeft(of: point), cellSize: cellSize),
      cell != judgedPointerCell
    else { return }
    judgedPointerCell = cell
    let isMouseHeld = ghostty_surface_mouse_captured(surface)
    setProgramLinkUnderPointer(isMouseHeld ? linkUnderPointer() : nil)
  }

  /// Cmd pressed or let go under a still pointer.
  func judgeProgramLink(afterModifiersOf event: NSEvent) {
    guard event.modifierFlags.contains(.command), let point = pointerInside() else {
      forgetProgramLink()
      return
    }
    judgeProgramLink(at: point, isCommandHeld: true)
  }

  /// `true` where a Cmd+press lands on a program link, which the program never
  /// sees. Any other press drops one whose release never came.
  func takesProgramLinkPress(_ event: NSEvent) -> Bool {
    let link = event.modifierFlags.contains(.command) ? programLinkUnderPointer : nil
    pressedProgramLink = link
    return link != nil
  }

  /// Opens a taken press's link, as libghostty opens its own on release, unless
  /// a drag or Cmd let go left it.
  func takesProgramLinkRelease() -> Bool {
    guard let link = pressedProgramLink else { return false }
    pressedProgramLink = nil
    if link == programLinkUnderPointer {
      onLinkClick?(GhosttyClickedLink(text: link, directory: currentDirectory, isHyperlink: false))
    }
    return true
  }

  func forgetProgramLink() {
    judgedPointerCell = nil
    setProgramLinkUnderPointer(nil)
  }

  private func pointerInside() -> NSPoint? {
    guard let window else { return nil }
    let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
    return bounds.contains(point) ? point : nil
  }

  private func linkUnderPointer() -> String? {
    guard let word = wordUnderPointer(), let line = viewportRow(word.row) else { return nil }
    return GhosttyHoveredLink.link(word: word.text, startingAt: word.column, in: line)
  }

  private func setProgramLinkUnderPointer(_ link: String?) {
    guard link != programLinkUnderPointer else { return }
    programLinkUnderPointer = link
    window?.invalidateCursorRects(for: self)
    // At once too, the pointer being inside the rect replaced; never once it left.
    if pointerInside() != nil { shownPointer.set() }
  }
}
