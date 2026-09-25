import AppKit
import MultishellProcess

/// Asks before quitting while terminals are open. Every open session is a
/// live pty, and quitting kills whatever is running in it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var liveTerminalCount: @MainActor () -> Int = { 0 }
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
    let (terminals, working) = (liveTerminalCount(), workingAgentCount())
    guard terminals > 0 else { return .terminateNow }

    let alert = QuitAlert.make(
      terminals: terminals, working: working, quit: t("action.quit"), cancel: t("action.cancel"))
    return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
  }
}
