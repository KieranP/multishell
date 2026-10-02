import MultishellCore
import SwiftUI

/// One button per group under `IconPalette`'s grid, its first symbol standing
/// for it, as the emoji picker's categories do.
struct IconPaletteGroupBar: View {
  let groups: [ProjectIcon.Group]
  let jump: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 0) {
        ForEach(groups, id: \.name) { group in
          Button {
            jump(group.name)
          } label: {
            Image(systemName: group.symbols.first ?? "square")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              // Shared width, not a fixed one: a fifteenth group would
              // otherwise run off the edge of the popover unnoticed.
              .frame(maxWidth: .infinity, minHeight: 20)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .help(group.name)
          .accessibilityLabel(group.name)
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 4)
      .padding(.bottom, 6)
    }
  }
}
