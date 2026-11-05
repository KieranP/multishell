import MultishellCore
import SwiftUI

/// The project icon's field, which pops up the `IconPalette`.
struct IconPicker: View {
  let kind: ProjectIcon.Kind
  let tint: Color
  let pick: (String) -> Void

  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented = true
    } label: {
      field
    }
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      IconPalette(kind: kind) { symbol in
        pick(symbol)
        isPresented = false
      }
    }
  }

  /// The glyph and a chevron, as the mockup drew it; its name is VoiceOver's value.
  private var field: some View {
    HStack(spacing: 6) {
      Image(systemName: kind.symbolName)
        .font(.system(size: 14))
        .foregroundStyle(tint)
      Image(systemName: "chevron.down")
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(SettingsColors.secondaryText)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(t("project.icon"))
    .accessibilityValue(name)
  }

  private var name: String {
    switch kind {
    case .folder: t("icon-picker.folder")
    case .symbol(let name): name
    }
  }
}
