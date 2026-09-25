import AppKit
import MultishellAppCore

/// Asked before quitting while terminals are open: Quit takes Return and
/// Cancel Escape, whatever language their titles are in.
@MainActor
enum QuitAlert {
  static func make(terminals: Int, working: Int, quit: String, cancel: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = t("quit.title")
    alert.informativeText = QuitConfirmation.message(terminals: terminals, working: working)
    alert.alertStyle = .warning
    alert.addButton(withTitle: quit)
    alert.addButton(withTitle: cancel).takesEscape()
    return alert
  }
}
