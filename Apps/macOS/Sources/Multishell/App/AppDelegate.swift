import AppKit
import MultishellAppCore
import MultishellCore
import MultishellProcess

/// Asks before quitting while terminals are open. Every open session is a
/// live pty, and quitting kills whatever is running in it.
final class AppDelegate: NSObject, NSApplicationDelegate {
  var openTerminalCount: @MainActor () -> Int = { 0 }
  var workingAgentCount: @MainActor () -> Int = { 0 }
  var willTerminate: @MainActor () -> Void = {}

  func applicationWillFinishLaunching(_ notification: Notification) {
    DescriptorLimit.raise()
  }

  func applicationWillTerminate(_ notification: Notification) {
    MainActor.assumeIsolated { willTerminate() }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    let (count, working) = MainActor.assumeIsolated { (openTerminalCount(), workingAgentCount()) }
    guard count > 0 else { return .terminateNow }

    let alert = NSAlert()
    alert.messageText = t("quit.title")
    alert.informativeText = QuitGuard.message(terminals: count, working: working)
    alert.alertStyle = .warning
    alert.addButton(withTitle: t("action.quit"))
    alert.addButton(withTitle: t("action.cancel"))
    return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
  }
}
