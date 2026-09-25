import AppKit

/// A confirmation whose lead buttons remove something, drawn red and still
/// answering Return; see Docs/design/smaller-decisions.md.
@MainActor
enum DestructiveAlert {
  /// The choices in the order shown, each drawn red, the first taking
  /// Return, and a Cancel after them taking Escape.
  static func make(title: String, message: String, choices: [String], cancel: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    for choice in choices {
      alert.addButton(withTitle: choice).hasDestructiveAction = true
    }
    let cancelButton = alert.addButton(withTitle: cancel)
    // With no choice to lead with, Cancel keeps the Return AppKit gave it.
    if !choices.isEmpty {
      cancelButton.takesEscape()
      leadTakesReturn(alert)
    }
    return alert
  }

  /// AppKit takes Return off a destructive button at every layout and paints a
  /// default one blue; see Docs/design/smaller-decisions.md.
  static func leadTakesReturn(_ alert: NSAlert) {
    guard let lead = alert.buttons.first, lead.hasDestructiveAction else { return }
    lead.keyEquivalent = "\r"
    lead.bezelColor = .systemRed
  }

  static func present(
    _ alert: NSAlert, in window: NSWindow
  ) async
    -> NSApplication.ModalResponse
  {
    await withCheckedContinuation { continuation in
      alert.beginSheetModal(for: window) { continuation.resume(returning: $0) }
      leadTakesReturn(alert)
      // The sheet lays out again as it goes up, after this call returns.
      Task { @MainActor in leadTakesReturn(alert) }
    }
  }

  /// Which choice was pressed, or `nil` for Cancel and for a sheet ended
  /// from under the user.
  static func chosen(_ response: NSApplication.ModalResponse, of count: Int) -> Int? {
    let first = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    let index = response.rawValue - first
    return (0..<count).contains(index) ? index : nil
  }
}
