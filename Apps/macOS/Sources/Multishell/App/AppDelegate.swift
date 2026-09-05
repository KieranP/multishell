import AppKit

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
    alert.messageText = "Quit Multishell?"
    alert.informativeText = Self.quitMessage(terminals: count, working: working)
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Quit")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
  }

  /// Working agents are counted apart from plain shells: a shell at a prompt
  /// loses nothing, an agent mid-task loses the task.
  static func quitMessage(terminals: Int, working: Int) -> String {
    let shells =
      terminals == 1
      ? "One terminal is still open and will be closed."
      : "\(terminals) terminals are still open and will be closed."
    switch working {
    case 0: return shells
    case 1: return shells + " One of them has an agent that is still working."
    default: return shells + " \(working) of them have agents that are still working."
    }
  }
}
