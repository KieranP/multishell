import MultishellCore
import SwiftUI

/// The project icon's field, which pops up the `IconPalette`.
struct IconPicker: View {
  let kind: ProjectIcon.Kind
  let tint: Color
  let choose: (String?) -> Void

  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented = true
    } label: {
      field
    }
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      IconPalette(kind: kind) { symbol in
        choose(symbol)
        isPresented = false
      }
    }
  }

  private var field: some View {
    HStack(spacing: 6) {
      Image(systemName: kind.symbolName).foregroundStyle(tint)
      switch kind {
      case .folder: Text(t("icon-picker.folder"))
      case .symbol(let name): Text(name).lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: 4)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .frame(width: 190)
  }
}
