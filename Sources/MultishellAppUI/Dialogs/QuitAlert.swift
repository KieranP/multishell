import AppKit
import MultishellAppCore

/// Asked before quitting while terminals are open: Quit takes Return and
/// Cancel Escape, whatever language their titles are in.
@MainActor
enum QuitAlert {
  static func make(
    terminals: Int, working: Int, quit: String = t("action.quit"),
    cancel: String = t("action.cancel")
  ) -> NSAlert {
    WarningAlert.make(
      title: t("quit.title"),
      message: QuitConfirmation.message(terminals: terminals, working: working), action: quit,
      cancel: cancel)
  }
}
