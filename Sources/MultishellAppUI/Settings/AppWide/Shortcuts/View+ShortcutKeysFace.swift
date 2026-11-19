import SwiftUI

extension View {
  /// Keys as the Yours cell draws them, so the button, the recorder and a
  /// pending answer line up at one width.
  func shortcutKeysFace() -> some View {
    font(.system(size: UIMetrics.settingsControlTextSize))
      .lineLimit(1)
      .padding(.horizontal, UIMetrics.settingsShortcutKeysSideInset)
      .padding(.vertical, UIMetrics.settingsControlVerticalInset)
      .frame(minWidth: UIMetrics.settingsShortcutKeysWidth)
  }
}
