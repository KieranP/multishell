import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Appearance: the theme, the terminal font and the UI size
/// every chrome measurement is derived from.
struct AppearanceSettingsTab: View {
  let model: AppModel

  @State private var fonts = InstalledFonts.detect()

  var body: some View {
    Form {
      Section {
        Picker("Theme:", selection: model.setting(\.appearance.themeID, write: model.setTheme)) {
          ForEach(model.themes) { Text($0.name).tag($0.id) }
        }
        InfoRow(
          "Theme files:",
          info:
            "Any .json in the folder appears in the list. The examples/ subfolder holds the built-ins to copy from; nothing in there is loaded."
        ) {
          Button("Open Folder") { model.revealThemesFolder() }
          IconButton.refresh(help: "Reload theme files") { model.reloadThemes() }
        }
        .controlSize(.small)
      }

      Section {
        DetectionPicker(
          label: "Terminal font:",
          selection: fontName,
          options: fonts.options(selected:),
          refresh: { fonts = InstalledFonts.detect() },
          info:
            "Monospaced families first, then every other installed family, since some programming fonts are not marked fixed-pitch. Refresh after installing one. Applies to every open terminal."
        )
        sizeRow(
          "Terminal size:", value: fontSize, current: model.workspace.appearance.fontSize,
          range: 9...24, info: "Terminal text. Applies to every open terminal.")
      }

      Section {
        sizeRow(
          "UI size:",
          value: model.setting(\.appearance.uiFontSize, write: model.setUIFontSize),
          current: model.workspace.appearance.uiFontSize,
          range: 10...18, info: "Sidebar, tabs and header. Row heights follow it.")
      }
    }
    .formStyle(.grouped)
  }

  private var fontName: Binding<String> {
    Binding(
      get: { model.workspace.appearance.fontName ?? FontDetection.systemID },
      set: { name in
        guard name != FontDetection.dividerID else { return }
        model.setFont(
          name: name == FontDetection.systemID ? nil : name,
          size: model.workspace.appearance.fontSize)
      }
    )
  }

  private var fontSize: Binding<Double> {
    Binding(
      get: { model.workspace.appearance.fontSize },
      set: { model.setFont(name: model.workspace.appearance.fontName, size: $0) }
    )
  }

  private func sizeRow(
    _ label: String, value: Binding<Double>, current: Double, range: ClosedRange<Double>,
    info: String
  ) -> some View {
    InfoRow(label, info: info) {
      Slider(value: value, in: range, step: 1)
      Text("\(Int(current)) pt")
        .monospacedDigit()
        .frame(width: 40, alignment: .trailing)
    }
  }
}
