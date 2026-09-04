import AppKit

/// Asks before quitting while terminals are open. Every open session is a
/// live pty, and quitting kills whatever is running in it.
final class AppDelegate: NSObject, NSApplicationDelegate {
  var openTerminalCount: @MainActor () -> Int = { 0 }
  var willTerminate: @MainActor () -> Void = {}

  func applicationWillTerminate(_ notification: Notification) {
    MainActor.assumeIsolated { willTerminate() }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    let count = MainActor.assumeIsolated { openTerminalCount() }
    guard count > 0 else { return .terminateNow }

    let alert = NSAlert()
    alert.messageText = "Quit Multishell?"
    alert.informativeText =
      count == 1
      ? "One terminal is still open and will be closed."
      : "\(count) terminals are still open and will be closed."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Quit")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
  }
}
