import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Appearance: the theme, the terminal font and the UI size
/// every chrome measurement is derived from.
struct AppAppearancePage: View {
  let model: AppModel

  /// The cached list, so building this view is not a walk over every family
  /// on the machine; Refresh asks again for someone who just installed one.
  @State private var fonts = InstalledFonts.all

  var body: some View {
    Form {
      Section {
        ThemePicker(title: t("appearance.theme"), model: model)
        InfoLabeledContent(t("appearance.theme-files"), info: t("appearance.theme-files-info")) {
          Button(t("appearance.open-folder")) { model.revealThemesFolder() }
          SettingsSymbolButton.refresh(help: t("appearance.reload-themes")) { model.reloadThemes() }
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
          t("appearance.terminal-size"),
          value: model.setting(\.appearance.terminalFontSize, write: model.setTerminalFontSize),
          range: Appearance.terminalFontSizes, info: t("appearance.terminal-size-info"))
      }

      Section {
        sizeRow(
          t("appearance.ui-size"),
          value: model.setting(\.appearance.uiFontSize, write: model.setUIFontSize),
          range: Appearance.uiFontSizes, info: t("appearance.ui-size-info"))
      }
    }
    .formStyle(.grouped)
  }

  private var fontName: Binding<String> {
    // A closure, not `model.setTerminalFontPickerID`: Swift 6.3's IRGen crashes on the
    // @isolated(any) thunk a method reference needs here.
    Binding(get: { model.terminalFontPickerID }, set: { model.setTerminalFontPickerID($0) })
  }

  private func sizeRow(
    _ label: String, value: Binding<Double>, range: ClosedRange<Double>, info: String
  ) -> some View {
    InfoLabeledContent(label, info: info) {
      Slider(value: value, in: range, step: 1)
      Text(t("appearance.points", Int(value.wrappedValue)))
        .monospacedDigit()
        .frame(width: 40, alignment: .trailing)
    }
  }
}
