import AppKit

/// The confirmations the app asks in an `NSAlert`, all in the warning style.
@MainActor
enum WarningAlert {
  static func make(title: String, message: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    return alert
  }

  /// One action taking Return and a Cancel after it taking Escape, whatever
  /// language their titles are in.
  static func make(
    title: String,
    message: String,
    action: String,
    cancel: String = t("action.cancel"),
  ) -> NSAlert {
    let alert = make(title: title, message: message)
    alert.addButton(withTitle: action)
    alert.addButton(withTitle: cancel).assignEscape()
    return alert
  }
}
