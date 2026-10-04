import AppKit
import GhosttyKit

/// The Edit menu over a pane, through libghostty's own binding actions so a
/// menu click does what the keystroke would.
extension GhosttySurfaceView: NSMenuItemValidation {
  @IBAction func copy(_ sender: Any?) {
    performBindingAction("copy_to_clipboard")
  }

  @IBAction func paste(_ sender: Any?) {
    performBindingAction("paste_from_clipboard")
  }

  @IBAction override func selectAll(_ sender: Any?) {
    performBindingAction("select_all")
  }

  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    switch item.action {
    case #selector(copy(_:)): surface.map(ghostty_surface_has_selection) ?? false
    case #selector(paste(_:)): GhosttyClipboard.hasPasteableType()
    default: surface != nil
    }
  }
}
