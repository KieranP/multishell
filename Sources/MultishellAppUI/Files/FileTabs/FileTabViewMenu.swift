import MultishellAppCore
import MultishellCore
import SwiftUI

/// Modified or Branch and Unified or Split as one menu, where a group is too
/// narrow for the bar's switches; see Docs/design/files/file-tabs.md.
struct FileTabViewMenu: View {
  let model: AppModel
  let tab: FileTab
  let offersChangeScope: Bool
  let offersLayout: Bool
  let palette: AreaPalette

  var body: some View {
    HeaderGlyphMenu(symbol: "slider.horizontal.3", help: t("file.view-options"), palette: palette) {
      if offersChangeScope {
        section(
          t("files-panel.change-scope"),
          options: ChangeScopeSwitch.options,
          selection: model.settingBinding(\.changeScope, write: model.setChangeScope),
        )
      }
      if offersLayout {
        section(
          t("file.layout"),
          options: FileTabLayoutSwitch.options,
          selection: FileTabLayoutSwitch.selection(in: model, for: tab),
        )
      }
    }
  }

  private func section<Value: Hashable>(
    _ title: String,
    options: [(title: String, value: Value)],
    selection: Binding<Value>,
  ) -> some View {
    Section(title) {
      Picker(title, selection: selection) {
        ForEach(options.indices, id: \.self) { index in
          Text(options[index].title).tag(options[index].value)
        }
      }
      .pickerStyle(.inline)
      .labelsHidden()
    }
  }
}
