import AppKit
import MultishellAppCore
import MultishellCore
import MultishellProcess

/// Asks before quitting while terminals are open. Every open session is a
/// live pty, and quitting kills whatever is running in it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var openTerminalCount: @MainActor () -> Int = { 0 }
  var workingAgentCount: @MainActor () -> Int = { 0 }
  var willTerminate: @MainActor () -> Void = {}

  func applicationWillFinishLaunching(_ notification: Notification) {
    DescriptorLimit.raise()
  }

  func applicationWillTerminate(_ notification: Notification) {
    willTerminate()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    let (count, working) = (openTerminalCount(), workingAgentCount())
    guard count > 0 else { return .terminateNow }

    let alert = Self.quitAlert(
      terminals: count, working: working, quit: t("action.quit"), cancel: t("action.cancel"))
    return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
  }

  static func quitAlert(terminals: Int, working: Int, quit: String, cancel: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = t("quit.title")
    alert.informativeText = QuitGuard.message(terminals: terminals, working: working)
    alert.alertStyle = .warning
    alert.addButton(withTitle: quit)
    // AppKit gives Escape to a button titled "Cancel" and to no other, so a
    // translated title would leave the alert with no way out.
    alert.addButton(withTitle: cancel).keyEquivalent = "\u{1b}"
    return alert
  }
}
