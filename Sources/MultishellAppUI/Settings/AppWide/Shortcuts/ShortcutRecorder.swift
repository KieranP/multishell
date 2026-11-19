import AppKit
import MultishellCore
import SwiftUI

/// The Yours cell while a row records: the modifiers pressed so far, or a prompt.
/// It ends when the row's step changes, which takes the view and its monitor away.
struct ShortcutRecorder: View {
  let take: (ShortcutRecorderInput) -> Void

  @State private var pressedModifiers: ShortcutModifiers = []
  @State private var monitor: ShortcutRecorderMonitor?

  var body: some View {
    Text(pressedModifiers.isEmpty ? t("shortcuts.type") : pressedModifiers.glyphs)
      .shortcutKeysFace()
      .background(SettingsColors.control, in: .rect(cornerRadius: UIMetrics.settingsControlRadius))
      .overlay {
        RoundedRectangle(cornerRadius: UIMetrics.settingsControlRadius)
          .strokeBorder(.tint, lineWidth: 2)
      }
      .accessibilityLabel(t("shortcuts.type"))
      .onAppear {
        monitor = ShortcutRecorderMonitor(
          windowNumber: NSApp.keyWindow?.windowNumber,
          onKey: receive,
        ) { take(.cancel) }
      }
      .onDisappear { monitor = nil }
  }

  private func receive(_ event: NSEvent) {
    if event.type == .flagsChanged {
      pressedModifiers = ShortcutModifiers(event.modifierFlags)
      return
    }
    take(ShortcutRecorderInput(event))
  }
}
