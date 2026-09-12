import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Appearance: the theme, the terminal font and the UI size
/// every chrome measurement is derived from.
struct AppearanceSettingsTab: View {
  let model: AppModel

  /// The cached list, so building this view is not a walk over every family
  /// on the machine; Refresh asks again for someone who just installed one.
  @State private var fonts = InstalledFonts.all

  var body: some View {
    Form {
      Section {
        Picker(
          t("appearance.theme"),
          selection: model.setting(\.appearance.themeID, write: model.setTheme)
        ) {
          ForEach(model.themes) { Text($0.name).tag($0.id) }
        }
        InfoRow(t("appearance.theme-files"), info: t("appearance.theme-files-info")) {
          Button(t("appearance.open-folder")) { model.revealThemesFolder() }
          IconButton.refresh(help: t("appearance.reload-themes")) { model.reloadThemes() }
        }
        .controlSize(.small)
      }

      Section {
        DetectionPicker(
          label: t("appearance.terminal-font"),
          selection: fontName,
          options: fonts.options(selected:),
          refresh: { fonts = InstalledFonts.reload() },
          info: t("appearance.font-info")
        )
        sizeRow(
          t("appearance.terminal-size"), value: fontSize,
          current: model.workspace.appearance.fontSize,
          range: 9...24, info: t("appearance.terminal-size-info"))
      }

      Section {
        sizeRow(
          t("appearance.ui-size"),
          value: model.setting(\.appearance.uiFontSize, write: model.setUIFontSize),
          current: model.workspace.appearance.uiFontSize,
          range: 10...18, info: t("appearance.ui-size-info"))
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
      Text(t("appearance.points", Int(current)))
        .monospacedDigit()
        .frame(width: 40, alignment: .trailing)
    }
  }
}
